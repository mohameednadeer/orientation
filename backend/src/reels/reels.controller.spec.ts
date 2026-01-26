import { Test, TestingModule } from '@nestjs/testing';
import { ReelsController } from './reels.controller';
import { ReelsService } from './reels.service';

describe('ReelsController', () => {
  let controller: ReelsController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ReelsController],
      providers: [ReelsService],
    }).compile();

    controller = module.get<ReelsController>(ReelsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
