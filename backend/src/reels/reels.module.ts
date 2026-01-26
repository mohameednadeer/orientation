import { Module } from '@nestjs/common';
import { ReelsService } from './reels.service';
import { ReelsController } from './reels.controller';
import { MongooseModule } from '@nestjs/mongoose';
import { Reel, ReelSchema } from './entities/reel.entity';
import { S3Module } from 'src/s3/s3.module';
import { Project, ProjectSchema } from 'src/projects/entities/project.entity';
import { User, UserSchema } from 'src/users/entities/user.entity';
import {
  Developer,
  DeveloperSchema,
} from 'src/developer/entities/developer.entity';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Reel.name, schema: ReelSchema },
      { name: User.name, schema: UserSchema },
      { name: Developer.name, schema: DeveloperSchema },
      { name: Project.name, schema: ProjectSchema },
    ]),
    S3Module,
  ],
  controllers: [ReelsController],
  providers: [ReelsService],
  exports: [ReelsService],
})
export class ReelsModule {}
