class PortfolioSkillEntity {
  final String id;
  final String skillName;
  final String category;
  final String proficiency;
  final int yearsOfExperience;
  final String description;

  const PortfolioSkillEntity({
    required this.id,
    required this.skillName,
    required this.category,
    required this.proficiency,
    required this.yearsOfExperience,
    required this.description,
  });

  factory PortfolioSkillEntity.empty({required String id}) {
    return PortfolioSkillEntity(
      id: id,
      skillName: '',
      category: '',
      proficiency: '',
      yearsOfExperience: 0,
      description: '',
    );
  }

  PortfolioSkillEntity copyWith({
    String? skillName,
    String? category,
    String? proficiency,
    int? yearsOfExperience,
    String? description,
  }) {
    return PortfolioSkillEntity(
      id: id,
      skillName: skillName ?? this.skillName,
      category: category ?? this.category,
      proficiency: proficiency ?? this.proficiency,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      description: description ?? this.description,
    );
  }
}
