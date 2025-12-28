import { BadRequestException, Injectable } from '@nestjs/common';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { QueryProjectDto } from './dto/query-project.dto';
import { Model, Types } from 'mongoose';
import { Project, ProjectDocument } from './entities/project.entity';
import { InjectModel } from '@nestjs/mongoose';
import { DeveloperService } from 'src/developer/developer.service';

@Injectable()
export class ProjectsService {
  constructor(
    @InjectModel(Project.name) private projectModel: Model<ProjectDocument>,
    private developerService: DeveloperService,
  ) {}

  async create(createProjectDto: CreateProjectDto) {
    // Verify developer exists
    const developer = await this.developerService.findOneDeveloper(
      createProjectDto.developerId,
    );

    if (!developer) {
      throw new BadRequestException('Developer not found');
    }

    // Normalize slug: lowercase and replace spaces with hyphens
    const slug = createProjectDto.slug
      .toLowerCase()
      .replace(/ /g, '-')
      .replace(/[^a-z0-9-]/g, '');

    // Check if project with same slug already exists
    const projectWithSameSlug = await this.projectModel.findOne({ slug });
    if (projectWithSameSlug) {
      throw new BadRequestException('Project with this slug already exists');
    }

    // Create project with normalized slug
    const project = new this.projectModel({
      ...createProjectDto,
      slug,
    });

    return project
      .save()
      .then((savedProject) => {
        return {
          message: 'Project created successfully',
          project: savedProject,
        };
      })
      .catch((error) => {
        // Handle duplicate key error (unique constraint violation)
        if (error.code === 11000) {
          throw new BadRequestException(
            'Project with this slug already exists',
          );
        }
        throw new BadRequestException(error.message);
      });
  }

  findAll(query: QueryProjectDto) {
    const {
      developerId,
      location,
      status,
      tags,
      featured,
      minPrice,
      maxPrice,
      limit,
      page,
      sortBy,
    } = query;
    // Exclude soft-deleted projects
    const mongoQuery = this.projectModel.find({ deletedAt: null });
    if (developerId) {
      mongoQuery.where('developerId').equals(developerId);
    }
    if (location) {
      mongoQuery.where('location').equals(location);
    }
    if (status) {
      mongoQuery.where('status').equals(status);
    }
    if (tags && tags.length > 0) {
      mongoQuery.where('tags').in(tags);
    }
    if (featured) {
      mongoQuery.where('featured').equals(featured);
    }
    if (minPrice) {
      mongoQuery.where('price').gte(minPrice);
    }
    if (maxPrice) {
      mongoQuery.where('price').lte(maxPrice);
    }
    if (limit) {
      mongoQuery.limit(limit);
    }
    if (page && limit) {
      mongoQuery.skip((page - 1) * limit);
    }
    if (sortBy) {
      // Sort by createdAt for 'newest', or by the specified field
      const sortField = sortBy === 'newest' ? 'createdAt' : sortBy;
      mongoQuery.sort({ [sortField]: -1 });
    } else {
      // Default sort by newest (createdAt)
      mongoQuery.sort({ createdAt: -1 });
    }
    return mongoQuery.exec();
  }

  async findOne(id: Types.ObjectId) {
    const project = await this.projectModel.findOne({
      _id: id,
      deletedAt: null,
    });
    if (!project) {
      throw new BadRequestException('Project not found');
    }
    return project;
  }

  async update(id: Types.ObjectId, updateProjectDto: UpdateProjectDto) {
    // If slug is being updated, normalize it
    if (updateProjectDto.slug) {
      updateProjectDto.slug = updateProjectDto.slug
        .toLowerCase()
        .replace(/ /g, '-')
        .replace(/[^a-z0-9-]/g, '');

      // Check if another project with the same slug exists
      const projectWithSameSlug = await this.projectModel.findOne({
        slug: updateProjectDto.slug,
        _id: { $ne: id },
      });
      if (projectWithSameSlug) {
        throw new BadRequestException('Project with this slug already exists');
      }
    }

    // If developerId is being updated, verify developer exists
    if (updateProjectDto.developerId) {
      const developer = await this.developerService.findOneDeveloper(
        updateProjectDto.developerId,
      );
      if (!developer) {
        throw new BadRequestException('Developer not found');
      }
    }

    const updatedProject = await this.projectModel
      .findByIdAndUpdate(id, updateProjectDto, {
        new: true,
        runValidators: true,
      })
      .catch((error) => {
        if (error.code === 11000) {
          throw new BadRequestException(
            'Project with this slug already exists',
          );
        }
        throw new BadRequestException(error.message);
      });

    if (!updatedProject) {
      throw new BadRequestException('Project not found');
    }

    return {
      message: 'Project updated successfully',
      project: updatedProject,
    };
  }

  async remove(id: Types.ObjectId) {
    // Soft delete by setting deletedAt timestamp
    const deletedProject = await this.projectModel.findByIdAndUpdate(
      id,
      { deletedAt: new Date() },
      { new: true },
    );

    if (!deletedProject) {
      throw new BadRequestException('Project not found');
    }

    return {
      message: 'Project deleted successfully',
      project: deletedProject,
    };
  }
}
