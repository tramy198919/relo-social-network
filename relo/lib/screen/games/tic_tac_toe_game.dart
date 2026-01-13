import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/service_locator.dart';
import '../../services/websocket_service.dart';
import '../../widgets/games/game_friend_selector.dart';

class TicTacToeGame extends StatefulWidget {
  final int difficulty; // 0: Easy, 1: Medium, 2: Hard
  final bool isVsFriend;
  final String? conversationId;
  final String? opponentId;
  final String? currentUserId;
  final List<dynamic>? participantIds;

  const TicTacToeGame({
    super.key,
    required this.difficulty,
    required this.isVsFriend,
    this.conversationId,
    this.opponentId,
    this.currentUserId,
    this.participantIds,
  });

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  List<String> board = List.filled(9, "");
  bool isPlayerTurn = true;
  String winner = "";
  bool isGameOver = false;
  bool isAiThinking = false;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isVsFriend && widget.conversationId != null) {
      _initRemoteSync();
      _loadExistingGameState();
    }
  }

  void _loadExistingGameState() async {
    try {
      final messages = await ServiceLocator.messageService.getMessages(widget.conversationId!, limit: 20);
      final moveMessages = messages.where((m) => m.content['type'] == 'game_move').toList();
      
      if (moveMessages.isNotEmpty) {
        // Reconstruct board from history
        final List<String> newBoard = List.filled(9, "");
        for (var i = moveMessages.length - 1; i >= 0; i--) {
          final moveData = moveMessages[i].content['text'];
          final data = jsonDecode(moveData);
          newBoard[data['index']] = data['symbol'];
        }
        
        setState(() {
          board = newBoard;
          final lastMove = moveMessages.first;
          final lastSymbol = lastMove.content['text'].contains('"symbol":"X"') ? "X" : "O";
          isPlayerTurn = (lastSymbol == "O");
          _checkWinner();
        });
      }
    } catch (e) {
      print("Error loading existing game state: $e");
    }
  }

  void _initRemoteSync() {
    _wsSubscription = webSocketService.stream.listen((data) {
      try {
        final decoded = jsonDecode(data);
        if (decoded['type'] == 'new_message') {
          final payload = decoded['payload'];
          final message = payload['message'];
          final content = message['content'];
          
          if (content['type'] == 'game_move' && 
              message['conversationId'] == widget.conversationId &&
              message['senderId'] != widget.currentUserId) {
            
            final moveData = jsonDecode(content['text']);
            final index = moveData['index'];
            final symbol = moveData['symbol'];
            
            if (board[index] == "") {
              setState(() {
                board[index] = symbol;
                isPlayerTurn = (symbol == "O"); // If opponent just played O, it's now X's turn
                _checkWinner();
              });
            }
          }
        }
      } catch (e) {
        print("Error parsing remote game move: $e");
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _handleTap(int index) {
    if (board[index] != "" || isGameOver || isAiThinking) return;

    // Strict turn locking for remote play
    if (widget.isVsFriend && widget.participantIds != null && widget.currentUserId != null) {
      // Deterministic Role: Smaller ID is X, Larger ID is O
      List<String> ids = widget.participantIds!.map((p) => 
        (p is Map) ? (p['id'] ?? p['userId']).toString() : p.toString()
      ).toList();
      ids.sort();
      
      String myRole = (widget.currentUserId == ids[0]) ? "X" : "O";
      bool isMyTurn = (isPlayerTurn && myRole == "X") || 
                      (!isPlayerTurn && myRole == "O");
                      
      if (!isMyTurn) return; // Not your turn!
    }
    
    setState(() {
      String symbol = isPlayerTurn ? "X" : "O";
      board[index] = symbol;
      _checkWinner();

      if (widget.isVsFriend && widget.conversationId != null) {
        // Send move to remote friend
        _sendRemoteMove(index, symbol);
        isPlayerTurn = !isPlayerTurn;
      } else if (!isGameOver) {
        // Local/AI logic
        if (!widget.isVsFriend) {
          isPlayerTurn = false;
          isAiThinking = true;
          // AI turn after a short delay
          Timer(const Duration(milliseconds: 600), _aiMove);
        } else {
          isPlayerTurn = !isPlayerTurn;
        }
      }
    });
  }

  void _sendRemoteMove(int index, String symbol) async {
    try {
      final moveData = jsonEncode({
        'index': index,
        'symbol': symbol,
      });
      
      await ServiceLocator.messageService.sendMessage(
        widget.conversationId!,
        {
          'type': 'game_move',
          'text': moveData,
        },
        widget.currentUserId!,
      );
    } catch (e) {
      print("Error sending remote move: $e");
    }
  }

  void _aiMove() {
    if (isGameOver || !mounted) return;

    int move = -1;
    switch (widget.difficulty) {
      case 0: // Easy: Random move
        move = _getRandomMove();
        break;
      case 1: // Medium: Block or win if possible, else random
        move = _getBestMove(isSmart: false);
        break;
      case 2: // Hard: Always try to win
        move = _getBestMove(isSmart: true);
        break;
    }

    if (move != -1) {
      setState(() {
        board[move] = "O";
        isPlayerTurn = true;
        isAiThinking = false;
        _checkWinner();
      });
    } else {
      setState(() {
        isAiThinking = false;
      });
    }
  }

  int _getRandomMove() {
    List<int> availableMoves = [];
    for (int i = 0; i < 9; i++) {
      if (board[i] == "") availableMoves.add(i);
    }
    if (availableMoves.isEmpty) return -1;
    return availableMoves[Random().nextInt(availableMoves.length)];
  }

  int _getBestMove({required bool isSmart}) {
    // 1. Check if can win
    for (int i = 0; i < 9; i++) {
      if (board[i] == "") {
        board[i] = "O";
        if (_checkWinnerFor(board, "O")) {
          board[i] = "";
          return i;
        }
        board[i] = "";
      }
    }

    // 2. Check if need to block
    for (int i = 0; i < 9; i++) {
      if (board[i] == "") {
        board[i] = "X";
        if (_checkWinnerFor(board, "X")) {
          board[i] = "";
          return i;
        }
        board[i] = "";
      }
    }

    if (isSmart) {
      // 3. Take center if available
      if (board[4] == "") return 4;
      
      // 4. Take corners
      List<int> corners = [0, 2, 6, 8];
      List<int> availableCorners = corners.where((c) => board[c] == "").toList();
      if (availableCorners.isNotEmpty) return availableCorners[Random().nextInt(availableCorners.length)];
    }

    // 5. Random
    return _getRandomMove();
  }

  bool _checkWinnerFor(List<String> b, String player) {
    List<List<int>> winLines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
      [0, 4, 8], [2, 4, 6] // Diagonals
    ];

    for (var line in winLines) {
      if (b[line[0]] == player && b[line[1]] == player && b[line[2]] == player) {
        return true;
      }
    }
    return false;
  }

  void _checkWinner() {
    if (_checkWinnerFor(board, "X")) {
      winner = "X";
      isGameOver = true;
    } else if (_checkWinnerFor(board, "O")) {
      winner = "O";
      isGameOver = true;
    } else if (!board.contains("")) {
      winner = "Draw";
      isGameOver = true;
    }

    if (isGameOver) {
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            winner == "Draw" ? "HÒA NHAU!" : "CHIẾN THẮNG!",
            style: const TextStyle(color: Color(0xFF7A2FC0), fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (winner != "Draw")
              Text(
                "Người thắng là: $winner",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A2FC0),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Chơi lại", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit game
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Thoát", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _resetGame() {
    setState(() {
      board = List.filled(9, "");
      isPlayerTurn = true;
      winner = "";
      isGameOver = false;
      isAiThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tac Toe', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7A2FC0),
        actions: [
          if (widget.isVsFriend)
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const GameFriendSelector(gameName: 'Tic Tac Toe'),
                );
              },
            ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF7A2FC0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPlayerTurn ? "Lượt của: X" : "Lượt của: O",
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A2FC0),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _handleTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF7A2FC0), width: 2),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        board[index],
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: board[index] == "X" ? Colors.blue : Colors.red,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
