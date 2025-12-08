import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from 'src/users/users.service';
import { LoginDto } from './dto/login.dto';
import * as bcrypt from 'bcrypt';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
  ) {}

  private async generateToken(user: {
    id: string;
    email: string;
    role: string;
  }): Promise<string> {
    const payload = { sub: user.id, email: user.email, role: user.role };
    return await this.jwtService.sign(payload);
  }

  async login(loginDto: LoginDto) {
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

    const token = await this.generateToken({
      id: user._id.toString(),
      email: user.email,
      role: user.role,
    });

    // Exclude password from response
    const { password, ...userWithoutPassword } = user.toObject();

    return {
      user: userWithoutPassword,
      token,
    };
  }

  async register(registerDto: RegisterDto) {
    const userExists = await this.usersService.findByEmail(registerDto.email);
    if (userExists) {
      throw new ConflictException('User already exists');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);
    const newUser = await this.usersService.create({
      ...registerDto,
      password: hashedPassword,
    });

    const token = await this.generateToken({
      id: newUser.user._id.toString(),
      email: newUser.user.email,
      role: newUser.user.role,
    });

    // Exclude password from response
    const { password, ...userWithoutPassword } = newUser.user.toObject();

    return {
      user: userWithoutPassword,
      token,
    };
  }
}
