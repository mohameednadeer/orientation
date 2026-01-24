import {
  Controller,
  Post,
  Body,
  Get,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import type { Request } from 'express';
import { AuthService } from './auth.service';
import { AuthGuard } from './auth.guard';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

interface AuthenticatedRequest extends Request {
  user?: { sub: string; email: string; role: string };
}

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // ==================== AUTHENTICATION ====================

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() loginDto: LoginDto, @Req() req: AuthenticatedRequest) {
    const deviceInfo = req.headers['user-agent'];
    const ipAddress =
      (req.headers['x-forwarded-for'] as string) ||
      req.ip ||
      req.socket.remoteAddress;
    return this.authService.login(loginDto, deviceInfo, ipAddress);
  }

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() body: RefreshTokenDto, @Req() req: AuthenticatedRequest) {
    const deviceInfo = req.headers['user-agent'];
    const ipAddress =
      (req.headers['x-forwarded-for'] as string) ||
      req.ip ||
      req.socket.remoteAddress;
    return this.authService.refreshTokens(
      body.refreshToken,
      deviceInfo,
      ipAddress,
    );
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  logout(@Body() body: RefreshTokenDto) {
    return this.authService.logout(body.refreshToken);
  }

  @Post('logout-all')
  @UseGuards(AuthGuard)
  @HttpCode(HttpStatus.OK)
  logoutAll(@Req() req: AuthenticatedRequest) {
    const userId = req.user?.sub;
    return this.authService.revokeAllUserTokens(userId!);
  }

  @Get('sessions')
  @UseGuards(AuthGuard)
  getActiveSessions(@Req() req: AuthenticatedRequest) {
    const userId = req.user?.sub;
    return this.authService.getActiveSessions(userId!);
  }

  // ==================== EMAIL VERIFICATION ====================

  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  verifyEmail(@Body('email') email: string, @Body('otp') otp: string) {
    return this.authService.verifyEmail(email, otp);
  }

  @Post('resend-verification')
  @HttpCode(HttpStatus.OK)
  resendVerificationOTP(@Body('email') email: string) {
    return this.authService.resendVerificationOTP(email);
  }

  // ==================== PASSWORD RESET ====================

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body('email') email: string) {
    return this.authService.forgotPassword(email);
  }

  @Post('verify-reset-otp')
  @HttpCode(HttpStatus.OK)
  verifyResetOTP(@Body('email') email: string, @Body('otp') otp: string) {
    return this.authService.verifyResetOTP(email, otp);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(
    @Body('email') email: string,
    @Body('otp') otp: string,
    @Body('newPassword') newPassword: string,
  ) {
    return this.authService.resetPassword(email, otp, newPassword);
  }
}
