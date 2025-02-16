import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appwrite/app_config.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Client client = Client()
      .setEndpoint("https://cloud.appwrite.io/v1")
      .setProject(AppConfig.projectId);
  Account account = Account(client);

  Databases databases = Databases(client);

  runApp(MainApp(account: account, database: databases));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.account, required this.database});
  final Account account;
  final Databases database;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: HomePage(account: account, database: database)),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.account, required this.database});
  final Account account;
  final Databases database;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  models.User? loggedInUser;
  List<Document> tasks = [];

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    tasks = await getTask();
    setState(() {});
  }

  Future<void> login(String email, String password) async {
    await widget.account.createEmailPasswordSession(
      email: email,
      password: password,
    );
    final user = await widget.account.get();
    setState(() {
      loggedInUser = user;
    });
  }

  Future<void> register(String email, String password, String name) async {
    await widget.account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    await login(email, password);
  }

  Future<void> logout() async {
    await widget.account.deleteSession(sessionId: 'current');
    setState(() {
      loggedInUser = null;
    });
  }

  Future<bool> createTask(String title, String description) async {
    try {
      final newTask = await widget.database.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        documentId: ID.unique(),
        data: {"title": title, "description": description, "completed": false},
      );

      setState(() {
        tasks.add(newTask);
      });

      return true;
    } on AppwriteException catch (e) {
      print(e);
      return false;
    }
  }

  Future<List<Document>> getTask() async {
    try {
      final response = await widget.database.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
      );

      return response.documents;
    } on AppwriteException catch (e) {
      print(e);
      return [];
    }
  }

  Future<bool> updateTask(String taskID, bool completed) async {
    try {
      final updatedTask = await widget.database.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        documentId: taskID,
        data: {"completed": completed},
      );

      final index = tasks.indexWhere((task) => task.$id == taskID);

      if (index != -1) {
        setState(() {
          tasks[index] = updatedTask;
        });
      }

      return true;
    } on AppwriteException catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> deleteTask(String taskID) async {
    try {
      await widget.database.deleteDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        documentId: taskID,
      );

      return true;
    } on AppwriteException catch (e) {
      print(e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appwrite Auth Example')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              loggedInUser != null
                  ? 'Logged in as ${loggedInUser!.name}'
                  : 'Not logged in',
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    login(emailController.text, passwordController.text);
                  },
                  child: Text('Login'),
                ),
                SizedBox(width: 16.0),
                ElevatedButton(
                  onPressed: () {
                    register(
                      emailController.text,
                      passwordController.text,
                      nameController.text,
                    );
                  },
                  child: Text('Register'),
                ),
                SizedBox(width: 16.0),
                ElevatedButton(
                  onPressed: () {
                    logout();
                  },
                  child: Text('Logout'),
                ),
              ],
            ),
            SizedBox(height: 24.0),
            Center(
              child: Text(
                "Database Operations",
                style: TextStyle(fontSize: 20),
              ),
            ),
            Expanded(
              child:
                  tasks.isEmpty
                      ? Center(child: Text('No Tasks yet'))
                      : ListView.builder(
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Dismissible(
                            key: Key(task.$id),
                            onDismissed: (_) => deleteTask(task.$id),
                            background: Container(
                              color: Colors.deepOrange.shade300,
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Iconsax.truck_remove_copy,
                                color: Colors.white,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(task.data['title']),
                              subtitle: Text(task.data['description']),
                              value: task.data['completed'],
                              onChanged: (value) {
                                if (value != null) {
                                  updateTask(task.$id, value);
                                }
                              },
                            ),
                          );
                        },
                        itemCount: tasks.length,
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Add Task'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(label: Text('Title')),
                    ),
                    TextFormField(
                      controller: descController,
                      decoration: InputDecoration(label: Text('Description')),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Row(
                      spacing: 4,
                      children: [
                        Text("Cancel"),
                        Icon(Iconsax.close_square_copy),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed:
                        () => {
                          if (titleController.text.isNotEmpty &&
                              descController.text.isNotEmpty)
                            {
                              createTask(
                                titleController.text,
                                descController.text,
                              ),
                              Navigator.pop(context),
                            },
                        },
                    child: Row(
                      spacing: 4,
                      children: [Text("Add Task"), Icon(Iconsax.add_copy)],
                    ),
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Iconsax.add_copy),
      ),
    );
  }
}
