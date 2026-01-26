import {
  IsOptional,
  IsString,
  IsEnum,
  IsMongoId,
  IsNumber,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export enum ProjectStatus {
  PLANNING = 'PLANNING',
  CONSTRUCTION = 'CONSTRUCTION',
  COMPLETED = 'COMPLETED',
  DELIVERED = 'DELIVERED',
}

export enum SortBy {
  NEWEST = 'newest',
  TRENDING = 'trending',
  SAVE_COUNT = 'saveCount',
  VIEW_COUNT = 'viewCount',
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
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  slug?: string;

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
