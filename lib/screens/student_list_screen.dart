import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> get _studentsStream {
    return FirebaseFirestore.instance
        .collection('students')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student List'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _studentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load students.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final students = snapshot.data?.docs ?? [];
          if (students.isEmpty) {
            return const Center(child: Text('No students found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = students[index].data();
              final studentId = _value(student, 'studentId');
              final name = _value(student, 'name', fallback: 'Unnamed student');
              final course = _value(student, 'course');

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    [studentId, course]
                        .where((value) => value.isNotEmpty)
                        .join('\n'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _value(
    Map<String, dynamic> data,
    String key, {
    String fallback = '',
  }) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }
}
