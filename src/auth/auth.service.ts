import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ConfigService } from '@nestjs/config';
import { UsersService } from 'src/users/users.service';
import { EmailService } from 'src/email/email.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import {
  RefreshToken,
  RefreshTokenDocument,
} from './entities/refresh-token.entity';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly emailService: EmailService,
    @InjectModel(RefreshToken.name)
    private readonly refreshTokenModel: Model<RefreshTokenDocument>,
  ) {}

  /**
   * Hash a token using SHA-256
   */
  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /**
   * Generate a short-lived access token (default: 15 minutes)
   */
  private generateAccessToken(user: {
    id: string;
    email: string;
    role: string;
  }): string {
    const payload = { sub: user.id, email: user.email, role: user.role };
    const expiresIn =
      this.configService.get<string>('JWT_ACCESS_EXPIRES_IN') || '15m';
    return this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: expiresIn as `${number}${'s' | 'm' | 'h' | 'd'}`,
    });
  }

  /**
   * Generate a longer-lived refresh token (default: 7 days)
   */
  private generateRefreshToken(user: {
    id: string;
    email: string;
    role: string;
  }): string {
    const payload = { sub: user.id, email: user.email, role: user.role };
    const expiresIn =
      this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '7d';
    return this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: expiresIn as `${number}${'s' | 'm' | 'h' | 'd'}`,
    });
  }

  /**
   * Store a hashed refresh token in the database
   */
  private async storeRefreshToken(
    userId: string,
    refreshToken: string,
    deviceInfo?: string,
    ipAddress?: string,
  ): Promise<void> {
    const hashedToken = this.hashToken(refreshToken);

    // Calculate expiry date based on JWT_REFRESH_EXPIRES_IN
    const expiresIn =
      this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '7d';
    const expiresAt = this.calculateExpiryDate(expiresIn);

    await this.refreshTokenModel.create({
      token: hashedToken,
      userId,
      deviceInfo,
      ipAddress,
      expiresAt,
    });
  }

  /**
   * Calculate expiry date from duration string (e.g., '7d', '24h', '30m')
   */
  private calculateExpiryDate(duration: string): Date {
    const now = new Date();
    const value = parseInt(duration.slice(0, -1), 10);
    const unit = duration.slice(-1);

    switch (unit) {
      case 'd':
        now.setDate(now.getDate() + value);
        break;
      case 'h':
        now.setHours(now.getHours() + value);
        break;
      case 'm':
        now.setMinutes(now.getMinutes() + value);
        break;
      case 's':
        now.setSeconds(now.getSeconds() + value);
        break;
      default:
        now.setDate(now.getDate() + 7); // Default to 7 days
    }

    return now;
  }

  /**
   * Get OTP expiry time in minutes from config (default: 2 minutes)
   */
  private getOtpExpiryMinutes(): number {
    return this.configService.get<number>('OTP_EXPIRY_MINUTES') || 2;
  }

  /**
   * Login user and return access + refresh tokens
   */
  async login(loginDto: LoginDto, deviceInfo?: string, ipAddress?: string) {
    const user = await this.usersService.findByEmail(loginDto.email);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.password) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(
      loginDto.password,
      user.password,
    );

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Check if email is verified
    if (!user.isEmailVerified) {
      throw new UnauthorizedException(
        'Please verify your email before logging in',
      );
    }

    const userPayload = {
      id: user._id.toString(),
      email: user.email,
      role: user.role,
    };

    const accessToken = this.generateAccessToken(userPayload);
    const refreshToken = this.generateRefreshToken(userPayload);

    // Store refresh token in database
    await this.storeRefreshToken(
      user._id.toString(),
      refreshToken,
      deviceInfo,
      ipAddress,
    );

    // Exclude password and OTP fields from response
    const {
      password,
      emailVerificationOTP,
      emailVerificationOTPExpires,
      passwordResetOTP,
      passwordResetOTPExpires,
      ...userWithoutSensitiveData
    } = user.toObject();

    return {
      user: userWithoutSensitiveData,
      accessToken,
      refreshToken,
    };
  }

  /**
   * Register new user and send verification OTP
   */
  async register(registerDto: RegisterDto) {
    const userExists = await this.usersService.findByEmail(registerDto.email);
    if (userExists) {
      throw new ConflictException('Email already registered');
    }

    // Generate OTP
    const otp = this.emailService.generateOTP();
    const otpExpires = new Date(
      Date.now() + this.getOtpExpiryMinutes() * 60 * 1000,
    );

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);
    const newUser = await this.usersService.create({
      ...registerDto,
      password: hashedPassword,
    });

    // Save OTP to user
    await this.usersService.updateOTP(newUser.user._id.toString(), {
      emailVerificationOTP: otp,
      emailVerificationOTPExpires: otpExpires,
    });

    // Send OTP email
    await this.emailService.sendVerificationOTP(registerDto.email, otp);

    return {
      success: true,
      message:
        'Registration successful. Please check your email for verification code.',
      email: registerDto.email,
    };
  }

  /**
   * Verify email with OTP
   */
  async verifyEmail(email: string, otp: string) {
    const user = await this.usersService.findByEmail(email);

    if (!user) {
      throw new BadRequestException('User not found');
    }

    if (user.isEmailVerified) {
      throw new BadRequestException('Email already verified');
    }

    if (!user.emailVerificationOTP) {
      throw new BadRequestException(
        'No verification code found. Please request a new one.',
      );
    }

    if (user.emailVerificationOTP !== otp) {
      throw new BadRequestException('Invalid verification code');
    }

    if (
      user.emailVerificationOTPExpires &&
      new Date() > user.emailVerificationOTPExpires
    ) {
      throw new BadRequestException('Verification code has expired');
    }

    // Mark email as verified and clear OTP
    await this.usersService.updateOTP(user._id.toString(), {
      isEmailVerified: true,
      emailVerificationOTP: null,
      emailVerificationOTPExpires: null,
    });

    return {
      success: true,
      message: 'Email verified successfully',
    };
  }

  /**
   * Resend verification OTP
   */
  async resendVerificationOTP(email: string) {
    const user = await this.usersService.findByEmail(email);

    if (!user) {
      throw new BadRequestException('User not found');
    }

    if (user.isEmailVerified) {
      throw new BadRequestException('Email already verified');
    }

    // Generate new OTP
    const otp = this.emailService.generateOTP();
    const otpExpires = new Date(
      Date.now() + this.getOtpExpiryMinutes() * 60 * 1000,
    );

    await this.usersService.updateOTP(user._id.toString(), {
      emailVerificationOTP: otp,
      emailVerificationOTPExpires: otpExpires,
    });

    await this.emailService.sendVerificationOTP(email, otp);

    return {
      success: true,
      message: 'Verification code sent to your email',
    };
  }

  /**
   * Forgot password - send reset OTP
   */
  async forgotPassword(email: string) {
    const user = await this.usersService.findByEmail(email);

    if (!user) {
      // Don't reveal if user exists for security
      return {
        success: true,
        message: 'If your email is registered, you will receive a reset code',
      };
    }

    // Generate OTP
    const otp = this.emailService.generateOTP();
    const otpExpires = new Date(
      Date.now() + this.getOtpExpiryMinutes() * 60 * 1000,
    );

    await this.usersService.updateOTP(user._id.toString(), {
      passwordResetOTP: otp,
      passwordResetOTPExpires: otpExpires,
    });

    await this.emailService.sendPasswordResetOTP(email, otp);

    return {
      success: true,
      message: 'Password reset code sent to your email',
    };
  }

  /**
   * Verify reset OTP (optional - verify before allowing password change)
   */
  async verifyResetOTP(email: string, otp: string) {
    const user = await this.usersService.findByEmail(email);

    if (!user) {
      throw new BadRequestException('User not found');
    }

    if (!user.passwordResetOTP) {
      throw new BadRequestException('No reset code found');
    }

    if (user.passwordResetOTP !== otp) {
      throw new BadRequestException('Invalid reset code');
    }

    if (
      user.passwordResetOTPExpires &&
      new Date() > user.passwordResetOTPExpires
    ) {
      throw new BadRequestException('Reset code has expired');
    }

    return {
      success: true,
      message: 'OTP verified. You can now reset your password.',
    };
  }

  /**
   * Reset password with OTP
   */
  async resetPassword(email: string, otp: string, newPassword: string) {
    const user = await this.usersService.findByEmail(email);

    if (!user) {
      throw new BadRequestException('User not found');
    }

    if (!user.passwordResetOTP) {
      throw new BadRequestException('No reset code found');
    }

    if (user.passwordResetOTP !== otp) {
      throw new BadRequestException('Invalid reset code');
    }

    if (
      user.passwordResetOTPExpires &&
      new Date() > user.passwordResetOTPExpires
    ) {
      throw new BadRequestException('Reset code has expired');
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password and clear OTP
    await this.usersService.updatePassword(user._id.toString(), hashedPassword);
    await this.usersService.updateOTP(user._id.toString(), {
      passwordResetOTP: null,
      passwordResetOTPExpires: null,
    });

    // Revoke all refresh tokens for security
    await this.revokeAllUserTokens(user._id.toString());

    return {
      success: true,
      message: 'Password reset successfully',
    };
  }

  /**
   * Refresh tokens with rotation (single-use refresh tokens)
   */
  async refreshTokens(
    refreshToken: string,
    deviceInfo?: string,
    ipAddress?: string,
  ) {
    try {
      // 1. Verify the refresh token JWT
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });

      // 2. Hash the token and find it in the database
      const hashedToken = this.hashToken(refreshToken);
      const storedToken = await this.refreshTokenModel.findOne({
        token: hashedToken,
        userId: payload.sub,
        isRevoked: false,
      });

      // 3. If token not found, it may have been reused (attack detected)
      if (!storedToken) {
        // Security: Revoke all tokens for this user (potential attack)
        await this.revokeAllUserTokens(payload.sub);
        throw new UnauthorizedException(
          'Refresh token reuse detected. All sessions have been revoked.',
        );
      }

      // 4. Delete the old refresh token (single-use)
      await this.refreshTokenModel.deleteOne({ _id: storedToken._id });

      // 5. Get the user
      const user = await this.usersService.findById(payload.sub);
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      // 6. Generate new tokens
      const userPayload = {
        id: user._id.toString(),
        email: user.email,
        role: user.role,
      };

      const newAccessToken = this.generateAccessToken(userPayload);
      const newRefreshToken = this.generateRefreshToken(userPayload);

      // 7. Store the new refresh token
      await this.storeRefreshToken(
        user._id.toString(),
        newRefreshToken,
        deviceInfo || storedToken.deviceInfo,
        ipAddress || storedToken.ipAddress,
      );

      return {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  /**
   * Logout - revoke the specific refresh token
   */
  async logout(refreshToken: string): Promise<{ message: string }> {
    const hashedToken = this.hashToken(refreshToken);
    await this.refreshTokenModel.deleteOne({ token: hashedToken });
    return { message: 'Logged out successfully' };
  }

  /**
   * Logout from all devices - revoke all refresh tokens for the user
   */
  async revokeAllUserTokens(userId: string): Promise<{ message: string }> {
    await this.refreshTokenModel.deleteMany({ userId });
    return { message: 'Logged out from all devices successfully' };
  }

  /**
   * Get all active sessions for a user
   */
  async getActiveSessions(userId: string) {
    const tokens = await this.refreshTokenModel
      .find({ userId, isRevoked: false })
      .select('deviceInfo ipAddress createdAt expiresAt')
      .sort({ createdAt: -1 });

    return tokens;
  }
}
