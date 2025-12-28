import {
  IsOptional,
  IsString,
  IsEnum,
  IsMongoId,
  IsBoolean,
  IsNumber,
  IsArray,
  Min,
  Max,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';

export enum ProjectStatus {
  PLANNING = 'PLANNING',
  CONSTRUCTION = 'CONSTRUCTION',
  COMPLETED = 'COMPLETED',
  DELIVERED = 'DELIVERED',
}

export enum SortBy {
  NEWEST = 'newest',
  TRENDING = 'trending',
  PRICE = 'price',
}

export class QueryProjectDto {
  @IsOptional()
  @IsMongoId()
  developerId?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsEnum(ProjectStatus)
  status?: ProjectStatus;

  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value === 'string') {
      return value.split(',').filter((tag) => tag.trim().length > 0);
    }
    return value;
  })
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  featured?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  minPrice?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  maxPrice?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Type(() => Number)
  page?: number;

  @IsOptional()
  @IsEnum(SortBy)
  sortBy?: SortBy;
}
