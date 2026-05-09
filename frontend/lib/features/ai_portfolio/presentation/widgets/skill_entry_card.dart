import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../domain/entities/portfolio_skill_entity.dart';
import 'portfolio_text_field.dart';

class SkillEntryCard extends StatelessWidget {
  final PortfolioSkillEntity skill;
  final VoidCallback onDelete;
  final ValueChanged<String> onSkillNameChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onProficiencyChanged;
  final ValueChanged<int> onYearsChanged;
  final ValueChanged<String> onDescriptionChanged;

  const SkillEntryCard({
    super.key,
    required this.skill,
    required this.onDelete,
    required this.onSkillNameChanged,
    required this.onCategoryChanged,
    required this.onProficiencyChanged,
    required this.onYearsChanged,
    required this.onDescriptionChanged,
  });

  static const _basePath = 'assets/images/ai_protifilo';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(color: AppColors.grey600, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightshadow,
            blurRadius: context.r(4),
            offset: Offset(context.r(4), context.r(4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Skill Entry 1',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: AppColors.blue900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppColors.red500,
                ),
              ),
              SizedBox(width: context.w(8)),
              Image.asset(
                '$_basePath/arrow.png',
                width: context.w(16),
                height: context.w(16),
                color: AppColors.blue900,
              ),
            ],
          ),
          SizedBox(height: context.h(16)),
          PortfolioTextField(
            label: 'Skill Name',
            hintText: 'e.g. Figma, Python, User Research',
            initialValue: skill.skillName,
            onChanged: onSkillNameChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioTextField(
            label: 'Category',
            hintText: 'e.g. UI/UX Design, Computer Vision',
            initialValue: skill.category,
            onChanged: onCategoryChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioTextField(
            label: 'Proficiency (Optional)',
            hintText: 'Enter Proficiency',
            initialValue: skill.proficiency,
            onChanged: onProficiencyChanged,
          ),
          SizedBox(height: context.h(8)),
          _YearsField(
            value: skill.yearsOfExperience,
            onChanged: onYearsChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioTextField(
            label: 'Description (Optional)',
            hintText: 'How did you use this skill?',
            initialValue: skill.description,
            onChanged: onDescriptionChanged,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _YearsField extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _YearsField({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Years of Experience (Optional)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: AppColors.blue900,
          ),
        ),
        SizedBox(height: context.h(2)),
        Container(
          height: context.h(32),
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(context.r(8)),
            border: Border.all(color: AppColors.lightBlue700, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: context.sp(13).clamp(12.0, 13.0),
                    color: AppColors.blue900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value > 0 ? value - 1 : 0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.keyboard_arrow_up, size: 16),
              ),
              SizedBox(width: context.w(4)),
              Text(
                'Years',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(11).clamp(11.0, 11.0),
                  color: AppColors.blue900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
