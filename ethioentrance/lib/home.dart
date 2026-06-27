
import 'package:flutter/material.dart';

import 'features/profile/screens/profile_screen.dart';
import 'features/subjects/screens/subject_list_screen.dart';
import 'features/ai_chat/screens/ai_chat_screen.dart';
import 'features/exam/screens/exam_screen.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  int _selectedIndex = 0;

  final List<String> _titles = const [
    'Home',
    'Courses',
    'Exams',
    'Ask AI',
    'Profile',
  ];

  late final List<Widget> _pages = [
    _HomeDashboard(
      onOpenCourses: () => _onItemTapped(1),
      onOpenAskAi: () => _onItemTapped(3),
      onOpenNationalExam: () => _onItemTapped(2)
      
       
    ),


    const  SubjectScreen(),
    const ExamScreen(),
    const AiResponsePage(),
    
    const ProfileScreen(),
  ];


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9C27B0), // Purple
              Color(0xFF673AB7), // Deep Purple
              Color(0xFF3F51B5), // Indigo
              Color(0xFF2196F3), // Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      _titles[_selectedIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _pages[_selectedIndex],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF9C27B0),
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book),label: 'Courses'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Exams'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'Ask AI'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// Dashboard-style Home tab.
class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.onOpenCourses,
    required this.onOpenAskAi,
    required this.onOpenNationalExam,
   
  });

  final VoidCallback onOpenCourses;
  final VoidCallback onOpenAskAi;
  final VoidCallback onOpenNationalExam;
 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ' Start from here your learning journey today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // 2x2 grid: (Courses, Ask AI) / (National Exam, Exam)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: (MediaQuery.of(context).size.height - 200) / 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: HomeCard(
                              title: 'Courses',
                              subtitle: 'PDF courses by grade',
                              icon: Icons.menu_book_rounded,
                              accentColor: Colors.green,
                              onTap: onOpenCourses,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HomeCard(
                              title: 'Ask AI',
                              subtitle: 'Get instant help',
                              icon: Icons.smart_toy_rounded,
                              accentColor: Colors.deepPurple,
                              onTap: onOpenAskAi,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      height: (MediaQuery.of(context).size.height - 200) / 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: HomeCard(
                              title: 'National Exam',
                              subtitle: 'Practice and prepare',
                              icon: Icons.assignment_rounded,
                              accentColor: Colors.orange,
                              onTap: onOpenNationalExam,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HomeCard(
                              title: 'Exam',
                              subtitle: 'Practice and prepare yourself',
                              icon: Icons.quiz_rounded,
                              accentColor: Colors.orange,
                              onTap: onOpenNationalExam,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      height: (MediaQuery.of(context).size.height - 200) / 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: HomeCard(
                              title: 'Personal Development',
                              subtitle: 'Build your righ personality daily',
                              icon: Icons.trending_up_rounded,
                              accentColor: Colors.teal,
                              onTap: onOpenNationalExam,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable dashboard card with border + ripple + hover.
class HomeCard extends StatefulWidget {
  const HomeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<HomeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _hovered ? widget.accentColor : Colors.grey.shade200;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.08 : 0.05),
              blurRadius: _hovered ? 18 : 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.accentColor),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}