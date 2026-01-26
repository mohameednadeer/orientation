import { PartialType } from '@nestjs/mapped-types';
import { CreateDeveloperDto } from './create-developer.dto';

/**
 * UpdateDeveloperDto - Allows updating developer data except projects
 * Note: Projects field is not included in CreateDeveloperDto, so it cannot be updated here.
 * Projects are managed separately through the Projects module.
 */
export class UpdateDeveloperDto extends PartialType(CreateDeveloperDto) {}
