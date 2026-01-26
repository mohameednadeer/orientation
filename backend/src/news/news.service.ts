import { Inject, Injectable } from '@nestjs/common';
import { CreateNewsDto } from './dto/create-news.dto';
import { UpdateNewsDto } from './dto/update-news.dto';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { NewsDocument } from './entities/news.entity';
import { ProjectDocument } from 'src/projects/entities/project.entity';
import { S3Service } from 'src/s3/s3.service';

@Injectable()
export class NewsService {
  constructor(
    @InjectModel('News') private newsModel: Model<NewsDocument>,
    @InjectModel('Project') private projectModel: Model<ProjectDocument>,
    private s3Service: S3Service,
  ) {}

  async create(createNewsDto: CreateNewsDto, thumbnail: Express.Multer.File) {
    const project = await this.projectModel.findById(createNewsDto.projectId);
    if (!project) {
      throw new Error('Project not found');
    }

    let thumbnailUrl = '';
    if (thumbnail) {
      const uploadResult = await this.s3Service.uploadFile(thumbnail, 'images');
      thumbnailUrl = uploadResult.url;
    }

    const news = new this.newsModel({
      ...createNewsDto,
      thumbnail: thumbnailUrl,
    });
    return (await news.save()).populate('projectId');
  }

  findAll() {
    return this.newsModel.find().populate('projectId').exec();
  }

  async findOne(id: Types.ObjectId) {
    const news = await this.newsModel.findById(id).populate('projectId').exec();
    if (!news) {
      throw new Error('News not found');
    }
    return news;
  }

  async update(
    id: Types.ObjectId,
    updateNewsDto: UpdateNewsDto,
    thumbnail?: Express.Multer.File,
  ) {
    const updateData = { ...updateNewsDto } as any;

    if (thumbnail) {
      const uploadResult = await this.s3Service.uploadFile(thumbnail, 'images');
      updateData.thumbnail = uploadResult.url;
    }

    const news = await this.newsModel
      .findByIdAndUpdate(id, updateData, { new: true })
      .populate('projectId')
      .exec();
    if (!news) {
      throw new Error('News not found');
    }
    return news;
  }

  async remove(id: Types.ObjectId) {
    const news = await this.newsModel.findById(id).exec();
    if (!news) {
      throw new Error('News not found');
    }

    // Delete thumbnail from S3 if it exists
    if (news.thumbnail) {
      try {
        const cloudFrontUrl = this.s3Service['cloudFrontUrl'];
        if (news.thumbnail.startsWith(cloudFrontUrl)) {
          const key = news.thumbnail.substring(cloudFrontUrl.length + 1);
          await this.s3Service.deleteFile(key);
        }
      } catch (error) {
        console.error('Error deleting thumbnail from S3:', error);
      }
    }

    await this.newsModel.findByIdAndDelete(id).exec();
    return news;
  }
}
