// Use this instead of dart:io for Web
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // REQUIRED for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/school.dart';

final schoolListProvider = StateNotifierProvider<SchoolListNotifier, AsyncValue<List<School>>>((ref) {
  return SchoolListNotifier();
});

class SchoolListNotifier extends StateNotifier<AsyncValue<List<School>>> {
  SchoolListNotifier() : super(const AsyncValue.loading()) {
    fetchSchools();
  }

  // ── READ ──────────────────────────────────────────────────────────────────
  Future<void> fetchSchools() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final res = await ApiService.get('/super/schools'); 
      final List list = res['data'] ?? [];
      state = AsyncValue.data(list.map((e) => School.fromJson(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── CREATE (Web-Safe with Bytes) ──────────────────────────────────────────
  Future<void> createSchool(Map<String, dynamic> data) async {
    try {
      // 1. Prepare FormData
      final formData = FormData.fromMap({
        'name': data['name'],
        'address': data['address'],
        'lat': data['lat'],
        'lng': data['lng'],
        'phone': data['phone'],
        'email': data['email'],
        'admin_name': data['admin_name'],
        'admin_email': data['admin_email'],
        'password': data['password'],
        'password_confirmation': data['password_confirmation'],
        'plan_id': data['plan_id'],
      });

      // 2. Attach Files as Bytes
      if (data['logo_bytes'] != null) {
        formData.files.add(MapEntry(
          'logo_url',
          MultipartFile.fromBytes(
            data['logo_bytes'] as Uint8List, 
            filename: 'logo.png',
            contentType: DioMediaType('image', 'png'),
          ),
        ));
      }

      if (data['admin_bytes'] != null) {
        formData.files.add(MapEntry(
          'photo_url',
          MultipartFile.fromBytes(
            data['admin_bytes'] as Uint8List, 
            filename: 'admin.png',
            contentType: DioMediaType('image', 'png'),
          ),
        ));
      }

      // ✅ FIX: Use '/schools' for creation. No $id needed here!
      await ApiService.postMultipart('/schools', formData);
      await fetchSchools(); 
    } catch (e) {
      rethrow; 
    }
  }

  // ── UPDATE (Web-Safe with Laravel PUT Fix) ────────────────────────────────
  Future<void> updateSchool(int id, Map<String, dynamic> data) async {
    final previousState = state;
    
    debugPrint("🚀 --- STARTING UPDATE DEBUG --- 🚀");
    debugPrint("Target School ID: $id");

    try {
      final formData = FormData.fromMap({
        'name': data['name'],
        'address': data['address'],
        'lat': data['lat'],
        'lng': data['lng'],
        'phone': data['phone'],
        'email': data['email'],
        '_method': 'PUT', // Spoofing for Laravel Multipart
      });

      if (data['logo_bytes'] != null) {
        final Uint8List bytes = data['logo_bytes'] as Uint8List;
        debugPrint("📸 Logo detected: ${bytes.length} bytes");

        formData.files.add(MapEntry(
          'logo_url', 
          MultipartFile.fromBytes(
            bytes,
            filename: 'school_logo_$id.jpg',
            contentType: DioMediaType('image', 'jpeg'), 
          ),
        ));
      }

      // ✅ This is where the $id IS required
      final res = await ApiService.postMultipart('/schools/$id', formData);
      
      debugPrint("✅ --- SERVER SUCCESS RESPONSE --- ✅");
      debugPrint(res.toString());

      await fetchSchools();
    } catch (e) {
      debugPrint("❌ --- UPLOAD FAILED --- ❌");
      debugPrint("Error: $e");
      state = previousState;
      rethrow;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<void> deleteSchool(int id) async {
    final previousState = state;
    state.whenData((schools) => state = AsyncValue.data(schools.where((s) => s.id != id).toList()));

    try {
      await ApiService.delete('/schools/$id');
    } catch (e) {
      state = previousState; 
      rethrow;
    }
  }
}