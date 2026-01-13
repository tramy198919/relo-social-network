import 'package:flutter/material.dart';
import 'games/tic_tac_toe_game.dart';
import 'games/bird_game.dart';
import '../widgets/games/game_friend_selector.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  // Helper classes for games (optional)
  
  void _selectDifficulty(BuildContext context, String gameName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn mức độ cho $gameName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDifficultyOption(context, 'Dễ', Colors.green, gameName, 0),
            _buildDifficultyOption(context, 'Trung bình', Colors.orange, gameName, 1),
            _buildDifficultyOption(context, 'Khó', Colors.red, gameName, 2),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(BuildContext context, String label, Color color, String gameName, int level) {
    return ListTile(
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.pop(context);
        if (gameName == 'Relo Bird') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BirdGame(difficulty: level)),
          );
        } else if (gameName == 'Tic Tac Toe') {
          _selectMode(context, level);
        }
      },
    );
  }

  void _selectMode(BuildContext context, int difficulty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn chế độ chơi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.computer),
              title: const Text('Chơi ngay (với Máy)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TicTacToeGame(
                      difficulty: difficulty,
                      isVsFriend: false,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Chơi với bạn bè'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showModalBottomSheet(
                  context: context,
                  builder: (context) => const GameFriendSelector(gameName: 'Tic Tac Toe'),
                );
                
                if (result != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TicTacToeGame(
                        difficulty: difficulty,
                        isVsFriend: true,
                        conversationId: result['conversationId'],
                        opponentId: result['friend'].id,
                        currentUserId: result['currentUserId'],
                        participantIds: result['participants'],
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Kho Trò Chơi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF7A2FC0),
        elevation: 2,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildGameCard(
              context,
              'Relo Bird',
              'Nhảy qua các chướng ngại vật',
              Icons.flutter_dash,
              Colors.blue,
              () => _selectDifficulty(context, 'Relo Bird'),
            ),
            _buildGameCard(
              context,
              'Tic Tac Toe',
              'Đấu trí X-O cực đỉnh',
              Icons.grid_3x3,
              Colors.orange,
              () => _selectDifficulty(context, 'Tic Tac Toe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
