import { Type } from 'class-transformer';
import { IsMongoId, IsNotEmpty, IsString } from 'class-validator';
import { Types } from 'mongoose';

export class CreateNewsDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsMongoId()
  @IsNotEmpty()
  @Type(() => Types.ObjectId)
  projectId: Types.ObjectId;

  @IsString()
  @IsNotEmpty()
  developer: string;
}
