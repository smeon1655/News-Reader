import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// =====================================================
// 1. MODEL CLASS
// =====================================================

class Article {
  final int userId;
  final int id;
  final String title;
  final String body;

  Article({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      userId: json['userId'],
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }
}

// =====================================================
// 2. REST API SERVICE
// =====================================================

class NewsService {
  final String apiUrl = 'https://jsonplaceholder.typicode.com/posts';

  Future<List<Article>> fetchArticles() async {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data.map((item) {
        return Article.fromJson(item);
      }).toList();
    } else {
      throw Exception('Failed to load articles');
    }
  }
}

// =====================================================
// 3. PROVIDER - STATE MANAGEMENT
// =====================================================

class NewsProvider extends ChangeNotifier {
  final NewsService _service = NewsService();

  List<Article> _articles = [];
  final Set<int> _favorites = {};

  bool _isLoading = false;
  String? _error;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get favoriteCount => _favorites.length;

  bool isFavorite(int id) {
    return _favorites.contains(id);
  }

  Future<void> fetchArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _articles = await _service.fetchArticles();
    } catch (e) {
      _error = 'Unable to load articles. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void toggleFavorite(int id) {
    if (_favorites.contains(id)) {
      _favorites.remove(id);
    } else {
      _favorites.add(id);
    }

    notifyListeners();
  }
}

// =====================================================
// 4. MAIN FUNCTION
// =====================================================

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NewsProvider()..fetchArticles(),
      child: const MyApp(),
    ),
  );
}

// =====================================================
// 5. MY APP
// =====================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'News Reader',

      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),

      home: const NewsScreen(),
    );
  }
}

// =====================================================
// 6. NEWS SCREEN
// =====================================================

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();

    // Search articles by title
    final filteredArticles = provider.articles.where((article) {
      return article.title.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'News Reader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        // Favorite count
        actions: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red),
              const SizedBox(width: 5),
              Text(
                '${provider.favoriteCount}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 15),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,

              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },

              decoration: InputDecoration(
                hintText: 'Search articles by title',
                prefixIcon: const Icon(Icons.search),

                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();

                    setState(() {
                      searchQuery = '';
                    });
                  },
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Loading State
          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          // Error State
          else if (provider.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 10),

                    Text(provider.error!),

                    const SizedBox(height: 15),

                    ElevatedButton.icon(
                      onPressed: () {
                        provider.fetchArticles();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          // Empty Search Result
          else if (filteredArticles.isEmpty)
            const Expanded(child: Center(child: Text('No articles found!')))
          // Success State - Article List
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.fetchArticles,

                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredArticles.length,

                  itemBuilder: (context, index) {
                    final article = filteredArticles[index];

                    final favorite = provider.isFavorite(article.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      elevation: 3,

                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),

                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            '${article.id}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),

                        title: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            article.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Favorite Button
                        trailing: IconButton(
                          icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                            color: favorite ? Colors.red : Colors.grey,
                          ),

                          onPressed: () {
                            provider.toggleFavorite(article.id);
                          },
                        ),

                        // Open Detail Screen
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return ArticleDetailScreen(article: article);
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================
// 7. ARTICLE DETAIL SCREEN
// =====================================================

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        actions: [
          Consumer<NewsProvider>(
            builder: (context, provider, child) {
              final favorite = provider.isFavorite(article.id);

              return IconButton(
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? Colors.red : Colors.white,
                ),

                onPressed: () {
                  provider.toggleFavorite(article.id);
                },
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              child: Text(
                '${article.id}',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              article.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Text(
              'Article Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              article.body,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),

            const SizedBox(height: 20),

            Text(
              'User ID: ${article.userId}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
