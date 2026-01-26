import { Type } from 'class-transformer';
import { IsMongoId, IsNotEmpty } from 'class-validator';
import { Types } from 'mongoose';

export class MongoIdDto {
  @IsMongoId()
  @IsNotEmpty()
  @Type(() => Types.ObjectId)
  id: Types.ObjectId;
}
