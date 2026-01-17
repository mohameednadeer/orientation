import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEnum,
  IsMongoId,
  IsBoolean,
  IsPhoneNumber,
} from 'class-validator';
import { Type } from 'class-transformer';
import { Types } from 'mongoose';

export class CreateProjectDto {
  @IsNotEmpty()
  heroVideo?: Express.Multer.File;

  @IsNotEmpty()
  logo: Express.Multer.File;

  @IsString()
  @IsNotEmpty()
  title: string;

  @IsMongoId()
  @IsNotEmpty()
  @Type(() => Types.ObjectId)
  developer: Types.ObjectId;

  @IsString()
  @IsNotEmpty()
  location: string;

  @IsEnum(['PLANNING', 'CONSTRUCTION', 'COMPLETED', 'DELIVERED'])
  @IsOptional()
  status?: 'PLANNING' | 'CONSTRUCTION' | 'COMPLETED' | 'DELIVERED';

  @IsString()
  @IsNotEmpty()
  script: string;

  @IsOptional()
  episodes?: any;

  @IsOptional()
  reels?: any;

  @IsOptional()
  inventory: Express.Multer.File;

  @IsOptional()
  pdf?: Express.Multer.File[];

  @IsPhoneNumber()
  @IsOptional()
  whatsappNumber?: string;

  @IsString()
  @IsOptional()
  mapsLocation?: string;

  @IsBoolean()
  @IsOptional()
  published?: boolean;
}
