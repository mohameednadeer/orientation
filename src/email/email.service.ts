import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private readonly configService: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.configService.get<string>('SMTP_HOST'),
      port: this.configService.get<number>('SMTP_PORT') || 587,
      secure: false, // true for 465, false for other ports
      auth: {
        user: this.configService.get<string>('SMTP_USER'),
        pass: this.configService.get<string>('SMTP_PASS'),
      },
    });
  }

  /**
   * Generate 4-digit OTP
   */
  generateOTP(): string {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  /**
   * Send Email Verification OTP
   */
  async sendVerificationOTP(email: string, otp: string): Promise<void> {
    const mailOptions = {
      from: `"Orientation App" <${this.configService.get('SMTP_FROM')}>`,
      to: email,
      subject: 'Email Verification Code - Orientation',
      text: `Your verification code is: ${otp}\n\nThis code will expire in 2 minutes.\n\nIf you didn't create an account, please ignore this email.`,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      this.logger.log(`Verification OTP sent to ${email}`);
    } catch (error) {
      this.logger.error('Error sending verification email:', error);
      throw new Error('Failed to send verification email');
    }
  }

  /**
   * Send Password Reset OTP
   */
  async sendPasswordResetOTP(email: string, otp: string): Promise<void> {
    const mailOptions = {
      from: `"Orientation App" <${this.configService.get('SMTP_FROM')}>`,
      to: email,
      subject: 'Password Reset Code - Orientation',
      text: `Your password reset code is: ${otp}\n\nThis code will expire in 2 minutes.\n\nIf you didn't request a password reset, please ignore this email.`,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      this.logger.log(`Password reset OTP sent to ${email}`);
    } catch (error) {
      this.logger.error('Error sending password reset email:', error);
      throw new Error('Failed to send password reset email');
    }
  }
}
