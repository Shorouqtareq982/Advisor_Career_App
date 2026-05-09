import '../../domain/entities/interview_entities.dart';

class InterviewRoles {
  InterviewRoles._();

  static const List<InterviewRole> roles = [
    InterviewRole(roleId: 'software_architect', roleName: 'Software Architect'),
    InterviewRole(roleId: 'software_engineering_tech_lead', roleName: 'Software Engineering Tech Lead'),
    InterviewRole(roleId: 'backend_dotnet_developer', roleName: 'Backend .NET Developer'),
    InterviewRole(roleId: 'backend_nodejs_developer', roleName: 'Backend Nodejs Developer'),
    InterviewRole(roleId: 'backend_python_developer', roleName: 'Backend Python Developer'),
    InterviewRole(roleId: 'backend_java_developer', roleName: 'Backend Java Developer'),
    InterviewRole(roleId: 'backend_php_developer', roleName: 'Backend PHP Developer'),
    InterviewRole(roleId: 'fullstack_mean_developer', roleName: 'Full Stack MEAN Developer'),
    InterviewRole(roleId: 'fullstack_mern_developer', roleName: 'Full Stack MERN Developer'),
    InterviewRole(roleId: 'frontend_react_developer', roleName: 'Frontend React Developer'),
    InterviewRole(roleId: 'frontend_angular_developer', roleName: 'Frontend Angular Developer'),
    InterviewRole(roleId: 'frontend_vue_developer', roleName: 'Frontend Vue Developer'),
    InterviewRole(roleId: 'react_native_developer', roleName: 'React Native Developer'),
    InterviewRole(roleId: 'flutter_developer', roleName: 'Flutter Developer'),
    InterviewRole(roleId: 'ai_engineer', roleName: 'AI Engineer'),
    InterviewRole(roleId: 'database_administrator', roleName: 'Database Administrator'),
    InterviewRole(roleId: 'data_engineer', roleName: 'Data Engineer'),
    InterviewRole(roleId: 'devops_engineer', roleName: 'DevOps Engineer'),
    InterviewRole(roleId: 'qa_engineer', roleName: 'Quality Assurance Engineer'),
    InterviewRole(roleId: 'qc_engineer', roleName: 'Quality Control Engineer'),
    InterviewRole(roleId: 'business_analyst', roleName: 'Business Analyst'),
    InterviewRole(roleId: 'oracle_developer', roleName: 'Oracle Developer'),
    InterviewRole(roleId: 'odoo_developer', roleName: 'Odoo Developer'),
    InterviewRole(roleId: 'wordpress_developer', roleName: 'WordPress Developer'),
    InterviewRole(roleId: 'zoho_developer', roleName: 'Zoho Developer'),
    InterviewRole(roleId: 'unity_game_developer', roleName: 'Unity Game Developer'),
    InterviewRole(roleId: 'it_manager', roleName: 'IT Manager'),
    InterviewRole(roleId: 'it_specialist', roleName: 'IT Specialist'),
    InterviewRole(roleId: 'it_help_desk', roleName: 'IT Help Desk'),
    InterviewRole(roleId: 'application_support', roleName: 'Application Support'),
    InterviewRole(roleId: 'sales_manager', roleName: 'Sales Manager'),
    InterviewRole(roleId: 'business_development_manager', roleName: 'Business Development Manager'),
    InterviewRole(roleId: 'account_manager', roleName: 'Account Manager'),
    InterviewRole(roleId: 'technical_sales_executive', roleName: 'Technical Sales Executive'),
    InterviewRole(roleId: 'b2b_sales_executive', roleName: 'B2B Sales Executive'),
    InterviewRole(roleId: 'telesales_customer_support', roleName: 'Telesales / Customer Support Representative'),
    InterviewRole(roleId: 'financial_manager', roleName: 'Financial Manager'),
    InterviewRole(roleId: 'chief_accountant', roleName: 'Chief Accountant'),
    InterviewRole(roleId: 'payroll_assistant', roleName: 'Payroll Assistant'),
    InterviewRole(roleId: 'hr_director', roleName: 'HR Director'),
    InterviewRole(roleId: 'od_supervisor', roleName: 'Organizational Development OD Supervisor'),
    InterviewRole(roleId: 'learning_development_specialist', roleName: 'Learning & Development Specialist'),
    InterviewRole(roleId: 'talent_management_specialist', roleName: 'Talent Management Specialist'),
    InterviewRole(roleId: 'administrative_manager', roleName: 'Administrative Manager'),
    InterviewRole(roleId: 'mechanical_automotive_engineer', roleName: 'Mechanical Automotive Engineer'),
    InterviewRole(roleId: 'instructional_designer', roleName: 'Instructional Designer'),
    InterviewRole(roleId: 'digital_marketing_manager', roleName: 'Digital Marketing Manager'),
    InterviewRole(roleId: 'graphic_designer', roleName: 'Graphic Designer'),
    InterviewRole(roleId: 'logistic_specialist', roleName: 'Logistic Specialist'),
    InterviewRole(roleId: 'warehouse_manager', roleName: 'Warehouse Manager'),
    InterviewRole(roleId: 'production_engineer', roleName: 'Production Engineer'),
    InterviewRole(roleId: 'cnc_engineer', roleName: 'CNC Engineer'),
    InterviewRole(roleId: 'electrical_bim_lead', roleName: 'Electrical BIM Lead'),
    InterviewRole(roleId: 'structural_engineer', roleName: 'Structural Engineer'),
    // UI/UX — commonly written both ways
    InterviewRole(roleId: 'uiux_designer', roleName: 'UI/UX Designer'),
    InterviewRole(roleId: 'data_analyst', roleName: 'Data Analyst'),
    InterviewRole(roleId: 'frontend_developer', roleName: 'Frontend Developer'),
    InterviewRole(roleId: 'software_engineer', roleName: 'Software Engineer'),
  ];

  /// Find a role by name — case-insensitive, trims spaces, normalises slashes & dots
  static InterviewRole? findByName(String input) {
    final normalised = _normalise(input);
    for (final role in roles) {
      if (_normalise(role.roleName) == normalised) return role;
    }
    return null;
  }

  /// Returns true if the given job title exists in the list
  static bool isSupported(String jobTitle) => findByName(jobTitle) != null;

  static String _normalise(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[\s./\\-]+'), ' ');
}
