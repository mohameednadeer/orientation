import { Module } from '@nestjs/common';
import { NewsService } from './news.service';
import { NewsController } from './news.controller';
import { MongooseModule } from '@nestjs/mongoose';
import { NewsSchema } from './entities/news.entity';
import { ProjectsModule } from 'src/projects/projects.module';
import { S3Module } from 'src/s3/s3.module';
import { ProjectSchema } from 'src/projects/entities/project.entity';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: 'News', schema: NewsSchema }]),
    MongooseModule.forFeature([{ name: 'Project', schema: ProjectSchema }]),
    S3Module,
  ],
  controllers: [NewsController],
  providers: [NewsService],
})
export class NewsModule {}
