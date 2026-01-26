import { IsEnum } from 'class-validator';

export class RoleUserDto {
  @IsEnum(['admin', 'user', 'developer', 'superadmin'])
  role: 'admin' | 'user' | 'developer' | 'superadmin';
}
