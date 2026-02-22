import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;

  const CourseCard({
    super.key,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    final title = course['title'] ?? 'Название курса';
    final description = course['description'] ?? 'Описание курса';
    final imageUrl = course['thumbnail_url'];
    final creatorName =
        course['profiles']?['full_name'] ?? 'Создатель курса (ФИО)';
    final creatorAvatar = course['profiles']?['avatar_url'];
    final courseId = course['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 0,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          context.push('/course/$courseId');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ ВЕРХНЯЯ ЧАСТЬ: КАРТИНКА + ТЕКСТ
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ КВАДРАТНАЯ КАРТИНКА 80x80
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[800],
                              child: const Icon(Icons.image,
                                  color: Colors.grey, size: 30),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[800],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey, size: 30),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[800],
                            child: const Icon(Icons.school,
                                color: Colors.grey, size: 30),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ ТЕКСТ СПРАВА
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ НИЖНЯЯ ЧАСТЬ: СОЗДАТЕЛЬ
              Row(
                children: [
                  // ✅ АВАТАРКА
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[700],
                    backgroundImage:
                        creatorAvatar != null && creatorAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(creatorAvatar)
                            : null,
                    child: creatorAvatar == null || creatorAvatar.isEmpty
                        ? const Icon(Icons.person, size: 14, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // ✅ ФИО СОЗДАТЕЛЯ
                  Text(
                    creatorName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
