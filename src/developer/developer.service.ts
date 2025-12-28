import { BadRequestException, Injectable } from '@nestjs/common';
import { UpdateDeveloperDto } from './dto/update-developer.dto';
import { Model, Types } from 'mongoose';
import { InjectModel } from '@nestjs/mongoose';
import { Developer, DeveloperDoc } from './entities/developer.entity';
import { CreateDeveloperDto } from './dto/create-developer.dto';
import { UpdateDeveloperScriptDto } from './dto/update-developer-project.dto';
@Injectable()
export class DeveloperService {
  constructor(
    @InjectModel(Developer.name)
    private developerModel: Model<DeveloperDoc>,
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
    return this.developerModel.findById(id).populate('projects name');
  }

  async findByName(name: string): Promise<DeveloperDoc | null> {
    return this.developerModel.findOne({
      name: { $regex: new RegExp(`^${name}$`, 'i') },
      deletedAt: null,
    });
  }

  async createDeveloper(createDeveloperDto: CreateDeveloperDto) {
    return await this.developerModel.create(createDeveloperDto);
  }

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

  remove(id: Types.ObjectId) {
    return `This action removes a #${id} developer`;
  }
}
