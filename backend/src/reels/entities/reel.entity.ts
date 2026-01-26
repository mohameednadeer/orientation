import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ReelDocument = Reel & Document;

@Schema({ timestamps: true })
export class Reel {
  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  videoUrl: string;

  @Prop({ required: false, default: null })
  thumbnail?: string;

  @Prop({ type: Types.ObjectId, ref: 'Project', required: true })
  projectId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'Developer', required: true })
  developerId: Types.ObjectId;

  @Prop({ default: 0 })
  viewCount: number;

  @Prop({ default: 0 })
  saveCount: number;

  @Prop({ required: true })
  s3Key: string;
}

export const ReelSchema = SchemaFactory.createForClass(Reel);
