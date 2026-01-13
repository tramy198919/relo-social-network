import 'dart:async';
import 'package:flutter/material.dart';

class BirdGame extends StatefulWidget {
  final int difficulty; // 0: Easy, 1: Medium, 2: Hard
  const BirdGame({super.key, required this.difficulty});

  @override
  State<BirdGame> createState() => _BirdGameState();
}

class _BirdGameState extends State<BirdGame> {
  // Game variables
  double birdY = 0;
  double initialPos = 0;
  double height = 0;
  double time = 0;
  double gravity = -4.5; // Smoother gravity
  double velocity = 2.2; // Predictable jump
  double birdWidth = 0.1;
  double birdHeight = 0.1;

  // Game state
  bool gameHasStarted = false;
  int score = 0;
  int highscore = 0;

  // Barrier variables
  List<double> barrierX = [2, 2 + 1.2];
  double barrierWidth = 0.5;
  List<List<double>> barrierHeight = [
    [0.6, 0.4],
    [0.4, 0.6],
  ];

  late Timer _gameTimer;
  double currentSpeed = 0;

  // Difficulty settings (Initial)
  double get initialSpeedMultiplier {
    switch (widget.difficulty) {
      case 0: return 0.008; // Very Slow
      case 1: return 0.012; // Normal
      case 2: return 0.016; // Fast
      default: return 0.012;
    }
  }

  double get gapSize {
    switch (widget.difficulty) {
      case 0: return 0.8; // Very Large gap
      case 1: return 0.7; // Large gap
      case 2: return 0.6; // Medium gap
      default: return 0.7;
    }
  }

  void startGame() {
    gameHasStarted = true;
    score = 0;
    currentSpeed = initialSpeedMultiplier;
    _gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      // Physical calculation
      time += 0.05;
      height = gravity * time * time + velocity * time;
      setState(() {
        birdY = initialPos - height;
      });

      // Increase speed over time/score (Slower progression)
      if (score > 0 && score % 10 == 0) {
        currentSpeed = initialSpeedMultiplier + (score * 0.0002);
      }

      // Move barriers
      setState(() {
        for (int i = 0; i < barrierX.length; i++) {
          barrierX[i] -= currentSpeed;
        }
      });

      // Recyle barriers
      if (barrierX[0] < -1.5) {
        barrierX[0] += 2.4;
        _randomizeBarrier(0);
        score++;
      }
      if (barrierX[1] < -1.5) {
        barrierX[1] += 2.4;
        _randomizeBarrier(1);
        score++;
      }

      // Check if bird is dead
      if (birdIsDead()) {
        timer.cancel();
        _showGameOverDialog();
      }
    });
  }

  void _randomizeBarrier(int index) {
    // Generate random heights that sum up to less than (2 - gapSize)
    // The total height of the screen in coordinate system is 2 (-1 to 1)
    double totalAvailable = 2.0 - gapSize;
    double top = 0.2 + (0.6 * (index + score) % 1.0); // Simple pseudo-random
    if (top > totalAvailable - 0.2) top = totalAvailable - 0.2;
    double bottom = totalAvailable - top;
    barrierHeight[index] = [top, bottom];
  }

  void jump() {
    setState(() {
      time = 0;
      initialPos = birdY;
    });
  }

  bool birdIsDead() {
    // Check if bird hit top or bottom
    if (birdY < -1 || birdY > 1) {
      return true;
    }

    // Check if bird hit barriers
    for (int i = 0; i < barrierX.length; i++) {
      if (barrierX[i] <= birdWidth &&
          barrierX[i] + barrierWidth >= -birdWidth &&
          (birdY <= -1 + barrierHeight[i][0] ||
              birdY >= 1 - barrierHeight[i][1])) {
        return true;
      }
    }

    return false;
  }

  void _showGameOverDialog() {
    if (score > highscore) highscore = score;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown,
        title: const Center(
          child: Text(
            "G A M E  O V E R",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        content: Text(
          "Điểm của bạn: $score\nKỷ lục: $highscore",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text("CHƠI LẠI", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit game
            },
            child: const Text("THOÁT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      birdY = 0;
      gameHasStarted = false;
      time = 0;
      initialPos = 0;
      barrierX = [2, 2 + 1.2];
      score = 0;
    });
  }

  @override
  void dispose() {
    if (gameHasStarted) _gameTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: gameHasStarted ? jump : startGame,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.blue,
                child: Center(
                  child: Stack(
                    children: [
                      // Bird
                      Bird(
                        birdY: birdY,
                        birdWidth: birdWidth,
                        birdHeight: birdHeight,
                      ),

                      // Start text
                      Container(
                        alignment: const Alignment(0, -0.3),
                        child: Text(
                          gameHasStarted ? "" : "N H Ấ N  Đ Ể  B Ắ T  Đ Ầ U",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Barriers
                      MyBarrier(
                        barrierX: barrierX[0],
                        barrierWidth: barrierWidth,
                        barrierHeight: barrierHeight[0][0],
                        isThisBottomBarrier: false,
                      ),
                      MyBarrier(
                        barrierX: barrierX[0],
                        barrierWidth: barrierWidth,
                        barrierHeight: barrierHeight[0][1],
                        isThisBottomBarrier: true,
                      ),
                      MyBarrier(
                        barrierX: barrierX[1],
                        barrierWidth: barrierWidth,
                        barrierHeight: barrierHeight[1][0],
                        isThisBottomBarrier: false,
                      ),
                      MyBarrier(
                        barrierX: barrierX[1],
                        barrierWidth: barrierWidth,
                        barrierHeight: barrierHeight[1][1],
                        isThisBottomBarrier: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 15,
              color: Colors.green,
            ),
            Expanded(
              child: Container(
                color: Colors.brown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("ĐIỂM", style: TextStyle(color: Colors.white, fontSize: 20)),
                        const SizedBox(height: 10),
                        Text(score.toString(), style: const TextStyle(color: Colors.white, fontSize: 35)),
                      ],
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("KỶ LỤC", style: TextStyle(color: Colors.white, fontSize: 20)),
                        const SizedBox(height: 10),
                        Text(highscore.toString(), style: const TextStyle(color: Colors.white, fontSize: 35)),
                      ],
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

class Bird extends StatelessWidget {
  final birdY;
  final double birdWidth;
  final double birdHeight;

  const Bird({this.birdY, required this.birdWidth, required this.birdHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment(0, (2 * birdY + birdHeight) / (2 - birdHeight)),
      child: Image.network(
        'https://pngimg.com/uploads/flappy_bird/flappy_bird_PNG28.png',
        width: MediaQuery.of(context).size.height * birdWidth / 2,
        height: MediaQuery.of(context).size.height * birdHeight / 2,
        fit: BoxFit.fill,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.flutter_dash, color: Colors.yellow, size: 50),
      ),
    );
  }
}

class MyBarrier extends StatelessWidget {
  final barrierWidth;
  final barrierHeight;
  final barrierX;
  final bool isThisBottomBarrier;

  const MyBarrier({
    this.barrierX,
    this.barrierWidth,
    this.barrierHeight,
    required this.isThisBottomBarrier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment((2 * barrierX + barrierWidth) / (2 - barrierWidth),
          isThisBottomBarrier ? 1 : -1),
      child: Container(
        color: Colors.green,
        width: MediaQuery.of(context).size.width * barrierWidth / 2,
        height: MediaQuery.of(context).size.height * 3 / 4 * barrierHeight / 2,
      ),
    );
  }
}
