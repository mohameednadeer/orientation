import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ProjectsService } from './projects.service';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { QueryProjectDto } from './dto/query-project.dto';
import { MongoIdDto } from 'src/common/mongoId.dto';
import { AuthGuard } from 'src/auth/auth.guard';
import { RolesGuard } from 'src/roles/roles.guard';
import { Roles } from 'src/roles/roles.decorator';
import { Role } from 'src/roles/roles.enum';

@Controller('projects')
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Post()
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  createProject(@Body() createProjectDto: CreateProjectDto) {
    return this.projectsService.create(createProjectDto);
  }

  @Get()
  findAllProjects(@Query() queryProjectDto: QueryProjectDto) {
    return this.projectsService.findAll(queryProjectDto);
  }

  // Suggested endpoints - implement these methods in ProjectsService
  @Get('featured')
  findFeaturedProjects(@Query('limit') limit?: string) {
    // return this.projectsService.findFeatured(limit);
  }

  @Get('trending')
  findTrendingProjects(@Query('limit') limit?: string) {
    // return this.projectsService.findTrending(limit);
  }

  @Get(':id')
  findOneProject(@Param() params: MongoIdDto) {
    return this.projectsService.findOne(params.id);
  }

  @Patch(':id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  updateProject(
    @Param() params: MongoIdDto,
    @Body() updateProjectDto: UpdateProjectDto,
  ) {
    return this.projectsService.update(params.id, updateProjectDto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  removeProject(@Param() params: MongoIdDto) {
    return this.projectsService.remove(params.id);
  }

  // Engagement Metrics - TODO: Implement these methods in ProjectsService
  @Put(':id/increment-view')
  @UseGuards(AuthGuard)
  incrementViewCount(@Param() params: MongoIdDto) {
    // return this.projectsService.incrementViewCount(params.id);
  }

  @Put(':id/increment-save')
  @UseGuards(AuthGuard)
  incrementSaveCount(@Param() params: MongoIdDto) {
    // return this.projectsService.incrementSaveCount(params.id);
  }

  @Put(':id/increment-share')
  @UseGuards(AuthGuard)
  incrementShareCount(@Param() params: MongoIdDto) {
    // return this.projectsService.incrementShareCount(params.id);
  }

  // Publishing - TODO: Implement these methods in ProjectsService
  @Put(':id/publish')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  publishProject(@Param() params: MongoIdDto) {
    // return this.projectsService.publish(params.id);
  }

  @Put(':id/unpublish')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  unpublishProject(@Param() params: MongoIdDto) {
    // return this.projectsService.unpublish(params.id);
  }

  // Featured Management - TODO: Implement these methods in ProjectsService
  @Put(':id/feature')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  featureProject(@Param() params: MongoIdDto) {
    // return this.projectsService.feature(params.id);
  }

  @Put(':id/unfeature')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles(Role.SUPERADMIN, Role.ADMIN)
  unfeatureProject(@Param() params: MongoIdDto) {
    // return this.projectsService.unfeature(params.id);
  }
}
