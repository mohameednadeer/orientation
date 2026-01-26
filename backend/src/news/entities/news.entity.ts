import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type NewsDocument = News & Document;

@Schema({ timestamps: true })
export class News {
  @Prop({ required: true })
  title: string;
  @Prop({ required: true })
  thumbnail: string;
  @Prop({ required: true, ref: 'Project', type: Types.ObjectId })
  projectId: string;
  @Prop({ required: true })
  developer: string;
}

export const NewsSchema = SchemaFactory.createForClass(News);
