import 'portfolio_skill_entity.dart';

class AIPortfolioEntity {
  final PortfolioCoverEntity cover;
  final List<PortfolioSkillEntity> skills;

  const AIPortfolioEntity({
    required this.cover,
    required this.skills,
  });

  factory AIPortfolioEntity.initial() {
    return const AIPortfolioEntity(
      cover: PortfolioCoverEntity(),
      skills: [],
    );
  }

  AIPortfolioEntity copyWith({
    PortfolioCoverEntity? cover,
    List<PortfolioSkillEntity>? skills,
  }) {
    return AIPortfolioEntity(
      cover: cover ?? this.cover,
      skills: skills ?? this.skills,
    );
  }
}

class PortfolioCoverEntity {
  final String fullName;
  final String professionalTitle;
  final String shortValueStatement;
  final String location;

  final String? profileImagePath;
  final String? profileImageName;

  final String? profileImageUrl;
  final String? profileImagePublicId;

  final String? coverImagePath;
  final String? coverImageName;

  final String? resumePath;
  final String? resumeFileName;

  const PortfolioCoverEntity({
    this.fullName = '',
    this.professionalTitle = '',
    this.shortValueStatement = '',
    this.location = '',
    this.profileImagePath,
    this.profileImageName,
    this.profileImageUrl,
    this.profileImagePublicId,
    this.coverImagePath,
    this.coverImageName,
    this.resumePath,
    this.resumeFileName,
  });

  PortfolioCoverEntity copyWith({
    String? fullName,
    String? professionalTitle,
    String? shortValueStatement,
    String? location,
    String? profileImagePath,
    String? profileImageName,
    String? profileImageUrl,
    String? profileImagePublicId,
    String? coverImagePath,
    String? coverImageName,
    String? resumePath,
    String? resumeFileName,
    bool clearProfileImage = false,
    bool clearCoverImage = false,
    bool clearResume = false,
  }) {
    return PortfolioCoverEntity(
      fullName: fullName ?? this.fullName,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      shortValueStatement: shortValueStatement ?? this.shortValueStatement,
      location: location ?? this.location,
      profileImagePath: clearProfileImage
          ? null
          : (profileImagePath ?? this.profileImagePath),
      profileImageName: clearProfileImage
          ? null
          : (profileImageName ?? this.profileImageName),
      profileImageUrl:
          clearProfileImage ? null : (profileImageUrl ?? this.profileImageUrl),
      profileImagePublicId: clearProfileImage
          ? null
          : (profileImagePublicId ?? this.profileImagePublicId),
      coverImagePath:
          clearCoverImage ? null : (coverImagePath ?? this.coverImagePath),
      coverImageName:
          clearCoverImage ? null : (coverImageName ?? this.coverImageName),
      resumePath: clearResume ? null : (resumePath ?? this.resumePath),
      resumeFileName:
          clearResume ? null : (resumeFileName ?? this.resumeFileName),
    );
  }
}
