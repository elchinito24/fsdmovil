class ApiRoutes {
  // Auth
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authLogout = '/auth/logout';
  static const String authMe = '/auth/me';

  // Workspaces
  static const String workspaces = '/workspaces';
  static String workspace(String id) => '/workspaces/$id';

  // Projects
  static const String projects = '/projects';
  static String project(String id) => '/projects/$id';

  // Documents (SRS)
  static const String documents = '/documents';
  static String document(String id) => '/documents/$id';
  static String documentRevisions(String id) => '/documents/$id/revisions';

  // Users
  static const String users = '/users';
  static String user(String id) => '/users/$id';
}
