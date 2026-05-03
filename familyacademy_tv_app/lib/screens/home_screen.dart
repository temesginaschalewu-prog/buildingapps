import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tv_session_controller.dart';
import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'course_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<CategoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getCategories();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TvSessionController>();
    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Family Academy TV'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                session.currentUser?.username ?? '',
                style: const TextStyle(fontSize: 16, color: Color(0xFFB8C6E3)),
              ),
            ),
          ),
          TextButton(
            onPressed: () => session.resetPairing(unpairServer: true),
            child: const Text('Reset TV'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<CategoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load categories.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          final categories = snapshot.data ?? const <CategoryItem>[];
          final active = categories.where((item) => !item.isComingSoon).toList();

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.45,
            ),
            itemCount: active.length,
            itemBuilder: (context, index) {
              final item = active[index];
              return TvFocusCard(
                autofocus: index == 0,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseScreen(category: item),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: item.imageUrl?.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => _fallback(item),
                            )
                          : _fallback(item),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x11000000),
                            Color(0xE6111826),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.price == null || item.price == 0
                                    ? 'Free'
                                    : '${item.price!.toStringAsFixed(0)} Birr',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (item.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD6E0F5),
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _fallback(CategoryItem item) {
    return Container(
      color: const Color(0xFF16304F),
      alignment: Alignment.center,
      child: Text(
        item.name.isNotEmpty ? item.name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
