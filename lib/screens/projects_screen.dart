import 'package:flutter/material.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/models/project.dart';
import 'package:go_router/go_router.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> projects = [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    print('TOKEN SET');
    loadProjects();
  }

  Future<void> loadProjects() async {
    try {
      final data = await ApiService.getProjects();

      print('API RESPONSE:');
      print(data);

      setState(() {
        projects = data.map<Project>((json) => Project.fromJson(json)).toList();
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      print('ERROR API:');
      print(e);

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Proyectos")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : projects.isEmpty
          ? const Center(child: Text("No hay proyectos"))
          : ListView.builder(
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(project.name),
                    subtitle: Text("Versión ${project.version}"),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      context.push('/editor/${project.id}');
                    },
                  ),
                );
              },
            ),
    );
  }
}
