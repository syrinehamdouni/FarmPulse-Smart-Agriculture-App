import 'package:flutter/material.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0.0;

  final List<OnboardingData> _pages = [
    OnboardingData(backgroundImage: "assets/bg2.png"),
    OnboardingData(backgroundImage: "assets/bg3.png"),
    OnboardingData(backgroundImage: "assets/bg4.png"),
    OnboardingData(backgroundImage: "assets/bg5.png", isLast: true),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int _currentPageIndex = _currentPage.round();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/bg1.png",
              fit: BoxFit.cover,
            ),
          ),

          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              double value = index - _currentPage;
              double translation = -value * MediaQuery.of(context).size.width;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..translate(translation)
                  ..rotateY(value <= 0 ? (value * math.pi / 1.5).clamp(-math.pi / 2, 0) : 0.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(_pages[index].backgroundImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: value < 0
                      ? Container(color: Colors.black.withOpacity((-value * 0.5).clamp(0, 0.5)))
                      : null,
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildDot(index, _currentPageIndex),
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: SizedBox(
                    height: 80,
                    child: Center(
                      child: _currentPageIndex == _pages.length - 1
                          ? _build3DCommencerButton()
                          : _buildNextArrow(),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
                  child: SizedBox(
                    height: 50,
                    child: _currentPageIndex == _pages.length - 1
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.bottomRight,
                            child: _build3DPasserButton(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, int currentPageIndex) {
    bool isSelected = currentPageIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 10,
      width: isSelected ? 25 : 10,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }

  Widget _buildNextArrow() {
    return GestureDetector(
      onTap: () => _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _build3DPasserButton() {
    return GestureDetector(
      onTap: () => _pageController.animateToPage(
        _pages.length - 1,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.fastOutSlowIn,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFBDBDBD),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Text(
          "PASSER",
          style: TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _build3DCommencerButton() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
      child: Container(
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          color: const Color(0xFF1C5000),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF388E3C),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "COMMENCER",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 30),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String backgroundImage;
  final bool isLast;

  OnboardingData({required this.backgroundImage, this.isLast = false});
}
