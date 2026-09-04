import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'class_students_page.dart';
import '../ui_helpers.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  Set<String> selectedClasses = {};
  Map<String, String> classNames = {}; // Store names for editing

  void _showAddClassModal(BuildContext context, {String? docId, String? initialName}) {
    final TextEditingController nameController = TextEditingController(text: initialName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                docId == null ? 'Sinf qo\'shish' : 'Sinfni tahrirlash',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Sinf nomi (Masalan: 10-A)',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      if (docId == null) {
                        await showLoading(context);
                        try {
                          await FirebaseFirestore.instance.collection('classes').add({
                            'name': nameController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Xatolik: $e (Firebase ruxsatnomasi (Rules) eskirgan bo\'lishi mumkin)')),
                            );
                          }
                          return;
                        }
                      } else {
                        // 1.5s animatsiya
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );
                        await Future.delayed(const Duration(milliseconds: 1500));
                        if (context.mounted) Navigator.pop(context); // close dialog
                        
                        await FirebaseFirestore.instance.collection('classes').doc(docId).update({
                          'name': nameController.text.trim(),
                        });
                        
                        setState(() {
                          selectedClasses.clear();
                        });
                      }
                      if (context.mounted) Navigator.pop(context); // close modal
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    docId == null ? 'Qo\'shish' : 'Saqlash',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteSelectedClasses() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: const Text('Tanlangan sinflar va ulardagi BARCHA o\'quvchilar butunlay o\'chirib yuboriladi. Tasdiqlaysizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish', style: TextStyle(color: Colors.black))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('O\'chirish', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.red)),
      );

      for (String classId in selectedClasses) {
        // Delete all students in class
        var studentsQuery = await FirebaseFirestore.instance.collection('students').where('class_id', isEqualTo: classId).get();
        for (var doc in studentsQuery.docs) {
          await doc.reference.delete();
        }
        // Delete the class
        await FirebaseFirestore.instance.collection('classes').doc(classId).delete();
      }

      if (mounted) Navigator.pop(context); // hide loading
      setState(() {
        selectedClasses.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (selectedClasses.isEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddClassModal(context),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Sinf qo\'shish',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  if (selectedClasses.length == 1)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          String classId = selectedClasses.first;
                          _showAddClassModal(context, docId: classId, initialName: classNames[classId]);
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('Tahrirlash', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (selectedClasses.length == 1) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _deleteSelectedClasses,
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('O\'chirish', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('classes').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.red));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Hozircha sinflar yo'q."));
                  }

                  var docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      String classId = docs[index].id;
                      String className = data['name'] ?? '';
                      classNames[classId] = className;

                      bool isSelected = selectedClasses.contains(classId);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('students')
                            .where('class_id', isEqualTo: classId)
                            .snapshots(),
                        builder: (context, studentSnap) {
                          int studentCount = studentSnap.hasData ? studentSnap.data!.docs.length : 0;
                          return Card(
                            elevation: isSelected ? 4 : 2,
                            color: isSelected ? Colors.red.shade50 : Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.red.shade700 : Colors.red,
                                child: isSelected 
                                    ? const Icon(Icons.check, color: Colors.white)
                                    : const Icon(Icons.class_, color: Colors.white),
                              ),
                              title: Text(
                                className,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Text('O\'quvchilar soni: $studentCount', style: const TextStyle(color: Colors.grey)),
                              trailing: isSelected 
                                  ? null 
                                  : const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                              onLongPress: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedClasses.remove(classId);
                                  } else {
                                    selectedClasses.add(classId);
                                  }
                                });
                              },
                              onTap: () {
                                if (selectedClasses.isNotEmpty) {
                                  setState(() {
                                    if (isSelected) {
                                      selectedClasses.remove(classId);
                                    } else {
                                      selectedClasses.add(classId);
                                    }
                                  });
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ClassStudentsPage(classId: classId, className: className),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
