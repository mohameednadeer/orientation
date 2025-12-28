import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsEnum,
  IsMongoId,
  IsUrl,
  IsArray,
  IsBoolean,
  IsDateString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { Types } from 'mongoose';

export class CreateProjectDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  slug: string;

  @IsMongoId()
  @IsNotEmpty()
  @Type(() => Types.ObjectId)
  developerId: Types.ObjectId;

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

  @IsMongoId()
  @IsOptional()
  @Type(() => Types.ObjectId)
  inventory?: any;

  @IsUrl()
  @IsNotEmpty()
  heroImage: string;

  @IsBoolean()
  @IsOptional()
  @Type(() => Boolean)
  featured?: boolean;
}
