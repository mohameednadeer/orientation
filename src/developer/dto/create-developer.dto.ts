import {
  IsString,
  IsNotEmpty,
  IsUrl,
  IsEmail,
  IsOptional,
  IsBoolean,
  IsObject,
  ValidateNested,
} from 'class-validator';

export class CreateDeveloperDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsUrl()
  @IsNotEmpty()
  logo: string;

  @IsUrl()
  @IsOptional()
  coverImage?: string;

  @IsEmail()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @IsNotEmpty()
  @IsOptional()
  socialMediaLink?: string;

  @IsString()
  @IsNotEmpty()
  location:string;

}