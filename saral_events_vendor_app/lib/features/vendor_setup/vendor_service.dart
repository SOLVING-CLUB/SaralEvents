import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vendor_models.dart';

class VendorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create or update vendor profile
  Future<VendorProfile> saveVendorProfile(VendorProfile profile) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if vendor profile already exists
      final existingProfile = await _supabase
          .from('vendor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existingProfile != null) {
        // Update existing profile
        final updatedData = {
          'business_name': profile.businessName,
          'vendor_name': profile.vendorName,
          'address': profile.address,
          'category': profile.category,
          'phone_number': profile.phoneNumber,
          'email': profile.email,
          'website': profile.website,
          'description': profile.description,
          'gst_number': profile.gstNumber,
          'pan_number': profile.panNumber,
          'aadhaar_number': profile.aadhaarNumber,
          'account_holder_name': profile.accountHolderName,
          'account_number': profile.accountNumber,
          'ifsc_code': profile.ifscCode,
          'bank_name': profile.bankName,
          'branch_name': profile.branchName,
          'services': profile.services,
          'profile_picture_url': profile.profilePictureUrl,
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        final resultList = await _supabase
            .from('vendor_profiles')
            .update(updatedData)
            .eq('user_id', userId)
            .select();
        if (resultList.isEmpty) {
          throw Exception('No profile updated');
        }
        final result = resultList.first;
        return VendorProfile.fromJson(result);
      } else {
        // Create new profile
        final newData = {
          'user_id': userId,
          'business_name': profile.businessName,
          'vendor_name': profile.vendorName,
          'address': profile.address,
          'category': profile.category,
          'phone_number': profile.phoneNumber,
          'email': profile.email,
          'website': profile.website,
          'description': profile.description,
          'gst_number': profile.gstNumber,
          'pan_number': profile.panNumber,
          'aadhaar_number': profile.aadhaarNumber,
          'account_holder_name': profile.accountHolderName,
          'account_number': profile.accountNumber,
          'ifsc_code': profile.ifscCode,
          'bank_name': profile.bankName,
          'branch_name': profile.branchName,
          'services': profile.services,
          'profile_picture_url': profile.profilePictureUrl,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        final resultList = await _supabase
            .from('vendor_profiles')
            .insert(newData)
            .select();
        if (resultList.isEmpty) {
          throw Exception('No profile inserted');
        }
        final result = resultList.first;
        return VendorProfile.fromJson(result);
      }
    } catch (e) {
      print('Error saving vendor profile: $e');
      throw Exception('Failed to save vendor profile: $e');
    }
  }

  // Get vendor profile by user ID
  Future<VendorProfile?> getVendorProfile(String userId) async {
    try {
      final result = await _supabase
          .from('vendor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (result == null) return null;
      return VendorProfile.fromJson(result);
    } catch (e) {
      throw Exception('Failed to get vendor profile: $e');
    }
  }

  // Upload document file to Supabase storage
  Future<String> uploadDocument(File file, String documentType, String vendorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '$userId/$documentType/$fileName';
      
      // Upload file to storage
      await _supabase.storage
          .from('vendor_documents')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final fileUrl = _supabase.storage
          .from('vendor_documents')
          .getPublicUrl(filePath);

      // Save document record to database
      final document = VendorDocument(
        vendorId: vendorId,
        documentType: documentType,
        fileName: fileName,
        filePath: filePath,
        fileUrl: fileUrl,
        uploadedAt: DateTime.now(),
      );

      final inserted = await _supabase
          .from('vendor_documents')
          .insert(document.toJson())
          .select()
          .single();
      
      print('DB insert success for document: ${inserted['id']} ${inserted['document_type']}');

      return fileUrl;
    } catch (e) {
      print('Error uploading document: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  // Get vendor documents
  Future<List<VendorDocument>> getVendorDocuments(String vendorId) async {
    try {
      final result = await _supabase
          .from('vendor_documents')
          .select()
          .eq('vendor_id', vendorId)
          .order('uploaded_at', ascending: false);

      return result.map((doc) => VendorDocument.fromJson(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get vendor documents: $e');
    }
  }

  // Delete vendor document
  Future<void> deleteDocument(String documentId, String filePath) async {
    try {
      // Delete from storage
      await _supabase.storage
          .from('vendor_documents')
          .remove([filePath]);

      // Delete from database
      await _supabase
          .from('vendor_documents')
          .delete()
          .eq('id', documentId);
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  // Backfill DB records from storage if files exist but DB rows are missing
  Future<int> syncDocumentsFromStorage(String vendorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      int insertedCount = 0;

      // List top-level entries under the user's folder (these should be document type folders)
      final topEntries = await _supabase.storage
          .from('vendor_documents')
          .list(path: userId);

      for (final entry in topEntries) {
        // Folders typically have null metadata; treat entry.name as documentType
        final documentType = entry.name;

        // List files inside the document type folder
        final files = await _supabase.storage
            .from('vendor_documents')
            .list(path: '$userId/$documentType');

        for (final f in files) {
          // Skip if this is a subfolder (no metadata)
          if (f.metadata == null) continue;
          final path = '$userId/$documentType/${f.name}';
          final fileName = f.name;

          // Check if DB row exists
          final existing = await _supabase
              .from('vendor_documents')
              .select('id')
              .eq('vendor_id', vendorId)
              .eq('file_path', path)
              .maybeSingle();
          if (existing != null) continue;

          final fileUrl = _supabase.storage
              .from('vendor_documents')
              .getPublicUrl(path);

          final doc = VendorDocument(
            vendorId: vendorId,
            documentType: documentType,
            fileName: fileName,
            filePath: path,
            fileUrl: fileUrl,
            uploadedAt: DateTime.now(),
          );

          await _supabase
              .from('vendor_documents')
              .insert(doc.toJson());
          insertedCount += 1;
        }
      }

      return insertedCount;
    } catch (e) {
      print('Error syncing documents from storage: $e');
      return 0;
    }
  }

  // Check if vendor profile exists
  Future<bool> hasVendorProfile(String userId) async {
    try {
      final result = await _supabase
          .from('vendor_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      return result != null;
    } catch (e) {
      return false;
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(File imageFile, String vendorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$userId/profile/$fileName';
      
      // Upload file to storage
      await _supabase.storage
          .from('vendor_documents')
          .upload(filePath, imageFile, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final fileUrl = _supabase.storage
          .from('vendor_documents')
          .getPublicUrl(filePath);

      // Update vendor profile with profile picture URL
      await _supabase
          .from('vendor_profiles')
          .update({'profile_picture_url': fileUrl})
          .eq('id', vendorId);

      return fileUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }
}
