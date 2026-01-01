import { BadRequestException, Injectable } from '@nestjs/common';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { QueryProjectDto } from './dto/query-project.dto';
import { Model, Types } from 'mongoose';
import { Project, ProjectDocument } from './entities/project.entity';
import { User, UserDocument } from 'src/users/entities/user.entity';
import { InjectModel } from '@nestjs/mongoose';
import { DeveloperService } from 'src/developer/developer.service';

@Injectable()
export class ProjectsService {
  constructor(
    @InjectModel(Project.name) private projectModel: Model<ProjectDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private developerService: DeveloperService,
  ) {}

  async create(createProjectDto: CreateProjectDto) {
    // Verify developer exists
    const developer = await this.developerService.findOneDeveloper(
      createProjectDto.developer,
    );

    if (!developer) {
      throw new BadRequestException('Developer not found');
    }

    // Normalize slug: lowercase and replace spaces with hyphens
    const slug = createProjectDto.title
      .toLowerCase()
      .replace(/ /g, '-')
      .replace(/[^a-z0-9-]/g, '');

    // crate project with normalized slug
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
            'Project with this Title already exists',
          );
        }
        throw new BadRequestException(error.message);
      });
  }

  findAll(query: QueryProjectDto) {
    const { developerId, location, status, title, slug, limit, page, sortBy } =
      query;
    // Exclude soft-deleted projects
    const mongoQuery = this.projectModel.find({ deletedAt: null });
    // populate developer with developer name
    mongoQuery.populate('developer');
    if (developerId) {
      mongoQuery.where('developer').equals(developerId);
    }
    if (location) {
      mongoQuery.where('location').equals(location);
    }
    if (status) {
      mongoQuery.where('status').equals(status);
    }
    if (title) {
      mongoQuery.where('title').equals(title);
    }
    if (slug) {
      mongoQuery.where('slug').equals(slug);
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
    // Find and increment view count atomically
    const project = await this.projectModel.findById(id);
    if (!project) {
      throw new BadRequestException('Project not found');
    }
    await this.incrementViewCount(id);
    return project;
  }

  async incrementViewCount(id: Types.ObjectId) {
    const updatedProject = await this.projectModel.findByIdAndUpdate(
      id,
      { $inc: { viewCount: 1 } },
      { new: true },
    );
    if (!updatedProject) {
      throw new BadRequestException('Project not found');
    }
    // Recalculate trending score after view increment
    await this.calculateTrendingScore(id);
    return updatedProject;
  }

  /**
   * Calculate trending score based on engagement metrics and time decay
   * Formula: (views * 1 + saves * 5) / (1 + hours_since_creation / 24)^1.5
   * This gives more weight to saves and applies time decay to favor recent content
   */
  async calculateTrendingScore(id: Types.ObjectId) {
    const project = await this.projectModel.findById(id);
    if (!project) {
      throw new BadRequestException('Project not found');
    }

    const views = project.viewCount || 0;
    const saves = project.saveCount || 0;
    // createdAt is added by Mongoose timestamps
    // Use _id.getTimestamp() as fallback if createdAt is not available
    const createdAt = (project as any).createdAt
      ? new Date((project as any).createdAt)
      : new Date(project._id.getTimestamp());
    const now = new Date();
    const hoursSinceCreation =
      (now.getTime() - createdAt.getTime()) / (1000 * 60 * 60);

    // Calculate trending score with time decay
    // Saves are weighted 5x more than views (saves indicate stronger interest)
    // Time decay: projects get less trending as they age
    const baseScore = views * 1 + saves * 5;
    const timeDecay = Math.pow(1 + hoursSinceCreation / 24, 1.5);
    const trendingScore = baseScore / timeDecay;

    // Update the trending score
    await this.projectModel.findByIdAndUpdate(id, {
      trendingScore: Math.round(trendingScore * 100) / 100, // Round to 2 decimal places
    });

    return trendingScore;
  }

  /**
   * Recalculate trending scores for all active projects
   * Useful for periodic updates via cron job
   */
  async recalculateAllTrendingScores() {
    const projects = await this.projectModel.find({ deletedAt: null });
    const updates = projects.map((project) =>
      this.calculateTrendingScore(project._id),
    );
    await Promise.all(updates);
    return {
      message: `Updated trending scores for ${projects.length} projects`,
    };
  }

  /**
   * Find trending projects sorted by trending score
   * Returns projects ranked from 1 to limit with position numbers
   */
  async findTrending(limit: number = 10) {
    const projects = await this.projectModel
      .find({ deletedAt: null })
      .populate('developer')
      .sort({ trendingScore: -1 })
      .limit(limit)
      .exec();

    // Add ranking position (1 to limit) to each project
    return projects.map((project, index) => ({
      rank: index + 1,
      ...project.toObject(),
    }));
  }

  async saveProject(id: Types.ObjectId, userId: Types.ObjectId) {
    // Verify project exists
    const project = await this.projectModel.findById(id);
    if (!project) {
      throw new BadRequestException('Project not found');
    }

    // Check if project is already saved by user
    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new BadRequestException('User not found');
    }
    if (user.savedProjects.includes(id)) {
      return { message: 'Project already saved' };
    }

    // Increment save count on project
    const updatedProject = await this.projectModel.findByIdAndUpdate(
      id,
      { $inc: { saveCount: 1 } },
      { new: true },
    );

    // Add project to user's saved projects (using $addToSet to avoid duplicates)
    await this.userModel.findByIdAndUpdate(
      userId,
      { $addToSet: { savedProjects: id } },
      { new: true },
    );

    // Recalculate trending score after save increment
    await this.calculateTrendingScore(id);

    return { message: 'Project saved successfully' };
  }

  async unsaveProject(id: Types.ObjectId, userId: Types.ObjectId) {
    // Verify project exists
    const project = await this.projectModel.findById(id);
    if (!project) {
      throw new BadRequestException('Project not found');
    }
    // Check if project is already saved by user
    const user = await this.userModel.findById(userId);
    if (!user) {
      throw new BadRequestException('User not found');
    }
    if (!user.savedProjects.includes(id)) {
      throw new BadRequestException('Project not saved');
    }

    // Decrement save count on project
    await this.projectModel.findByIdAndUpdate(
      id,
      { $inc: { saveCount: -1 } },
      { new: true },
    );

    // Remove project from user's saved projects (using $pull to remove single occurrence)
    await this.userModel.findByIdAndUpdate(
      userId,
      { $pull: { savedProjects: id } },
      { new: true },
    );

    // Recalculate trending score after save decrement
    await this.calculateTrendingScore(id);

    return { message: 'Project unsaved successfully' };
  }

  async update(id: Types.ObjectId, updateProjectDto: UpdateProjectDto) {
    // If slug is being updated, normalize it
    if (updateProjectDto.title) {
      updateProjectDto.title = updateProjectDto.title
        .toLowerCase()
        .replace(/ /g, '-')
        .replace(/[^a-z0-9-]/g, '');

      // Check if another project with the same slug exists
      const projectWithSameSlug = await this.projectModel.findOne({
        title: updateProjectDto.title,
        _id: { $ne: id },
      });
      if (projectWithSameSlug) {
        throw new BadRequestException('Project with this slug already exists');
      }
    }

    // If developerId is being updated, verify developer exists
    if (updateProjectDto.developer) {
      const developer = await this.developerService.findOneDeveloper(
        updateProjectDto.developer,
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
