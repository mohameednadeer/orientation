import { BadRequestException, Injectable } from '@nestjs/common';
import { UpdateDeveloperDto } from './dto/update-developer.dto';
import { Model, Types } from 'mongoose';
import { InjectModel } from '@nestjs/mongoose';
import { Developer, DeveloperDoc } from './entities/developer.entity';
import { CreateDeveloperDto } from './dto/create-developer.dto';
import { UpdateDeveloperScriptDto } from './dto/update-developer-project.dto';
import { S3Service } from 'src/s3/s3.service';

@Injectable()
export class DeveloperService {
  constructor(
    @InjectModel(Developer.name)
    private developerModel: Model<DeveloperDoc>,
    private s3Service: S3Service,
  ) {}

  async findAllDevelopers() {
    // find all developers except deleted ones
    return await this.developerModel
      .find({ deletedAt: null })
      .then((developers) => {
        return {
          message: 'Developers fetched successfully',
          developers,
        };
      })
      .catch((error) => {
        throw new BadRequestException(error.message);
      });
  }

  findOneDeveloper(id: Types.ObjectId) {
    return this.developerModel.findById(id).populate('projects');
  }

  async findByName(name: string): Promise<DeveloperDoc | null> {
    return this.developerModel.findOne({
      name: { $regex: new RegExp(`^${name}$`, 'i') },
      deletedAt: null,
    });
  }

  async createDeveloper(createDeveloperDto: CreateDeveloperDto) {
    const developerExists = await this.findByName(createDeveloperDto.name);
    console.log(developerExists);
    if (developerExists) {
      throw new BadRequestException('Developer with this name already exists');
    }

    const emailExists = await this.developerModel.findOne({
      email: createDeveloperDto.email,
      deletedAt: null,
    });
    if (emailExists) {
      throw new BadRequestException('Developer with this email already exists');
    }

    const developer = new this.developerModel({
      ...createDeveloperDto,
    });
    return await developer
      .save()
      .then((dev) => {
        return {
          message: 'Developer created successfully',
          developer: dev,
        };
      })
      .catch((error) => {
        throw new BadRequestException(error.message);
      });
  }

  // update developer project script by developer
  async updateDeveloperScript(
    id: Types.ObjectId,
    updateDeveloperScriptDto: UpdateDeveloperScriptDto,
  ) {
    return await this.developerModel
      .findByIdAndUpdate(
        id,
        { script: updateDeveloperScriptDto.script },
        { new: true },
      )
      .then((updatedDeveloper) => {
        return {
          message: 'Developer project updated successfully',
          developer: updatedDeveloper,
        };
      })
      .catch((error) => {
        throw new BadRequestException(error.message);
      });
  }

  // update developer details by admin or superadmin
  async updateDeveloper(
    id: Types.ObjectId,
    updateDeveloperDto: UpdateDeveloperDto,
    userEmail?: string,
  ) {
    // Find the developer
    const developer = await this.developerModel.findById(id);
    if (!developer) {
      throw new BadRequestException('Developer not found');
    }

    if (userEmail && developer.email && developer.email !== userEmail) {
      throw new BadRequestException(
        'You can only update your own developer profile',
      );
    }

    const updateData = { ...updateDeveloperDto };
    delete (updateData as any).projects;

    return await this.developerModel
      .findByIdAndUpdate(id, updateData, { new: true })
      .then((updatedDeveloper) => {
        return {
          message: 'Developer updated successfully',
          developer: updatedDeveloper,
        };
      })
      .catch((error) => {
        throw new BadRequestException(error.message);
      });
  }

  async remove(id: Types.ObjectId) {
    try {
      const deletedDeveloper = await this.developerModel.findByIdAndDelete(id);
      if (!deletedDeveloper) {
        throw new BadRequestException('Developer not found');
      }
      return {
        message: 'Developer deleted successfully',
        developer: deletedDeveloper,
      };
    } catch (error) {
      throw new BadRequestException(error.message);
    }
  }
}
