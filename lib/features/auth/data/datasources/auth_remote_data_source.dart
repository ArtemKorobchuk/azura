import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';
import '../../../../core/errors/failures.dart';

abstract class AuthRemoteDataSource {
  Future<UserEntity> login(String email, String password);
  Future<UserEntity> register(String email, String password, String name);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl(this._auth, this._firestore);

  Future<UserEntity> _userFromFirebase(User? user) async {
    if (user == null) throw ServerFailure('User is null');
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw ServerFailure('User data not found');
    
    return UserEntity(
      id: user.uid,
      name: doc['name'] as String,
      email: doc['email'] as String,
      phone: doc['phone'] as String?,
    );
  }

  @override
  Future<UserEntity> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await _userFromFirebase(userCredential.user);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<UserEntity> register(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return await _userFromFirebase(userCredential.user);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Failure _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return ServerFailure('Некорректный email');
      case 'user-disabled':
        return ServerFailure('Пользователь заблокирован');
      case 'user-not-found':
        return ServerFailure('Пользователь не найден');
      case 'wrong-password':
        return ServerFailure('Неверный пароль');
      default:
        return ServerFailure(e.message ?? 'Ошибка аутентификации');
    }
  }
}