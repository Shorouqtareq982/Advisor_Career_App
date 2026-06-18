import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/ai_portfolio_model.dart';

class AIPortfolioRemoteDataSource {
  final ApiClient _apiClient;

  AIPortfolioRemoteDataSource({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? apiClientSingleton;

  Future<List<PortfolioTemplateModel>> getTemplates() async {
    final response = await _apiClient.get(ApiConstants.portfolioTemplates);

    final data = Map<String, dynamic>.from(response.data as Map);
    final templates = data['templates'] as List<dynamic>? ?? const [];

    return templates
        .whereType<Map>()
        .map(
          (item) => PortfolioTemplateModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<String> previewTemplate(int templateId) async {
    final response = await _apiClient.get(
      ApiConstants.portfolioPreviewTemplate(templateId),
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'text/html',
        },
      ),
    );

    return response.data.toString();
  }

  Future<PortfolioImageUploadResponseModel> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
    });

    final response = await _apiClient.post(
      ApiConstants.portfolioUploadImage,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return PortfolioImageUploadResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AIPortfolioResponseModel> createPortfolio(
    AIPortfolioRequestModel request,
  ) async {
    final response = await _apiClient.post(
      ApiConstants.portfolioCreate,
      data: request.toJson(),
    );

    return AIPortfolioResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AIPortfolioResponseModel> updatePortfolio({
    required String portfolioId,
    required AIPortfolioRequestModel request,
  }) async {
    final response = await _apiClient.put(
      ApiConstants.portfolioById(portfolioId),
      data: request.toJson(),
    );

    return AIPortfolioResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AIPortfolioResponseModel> getPortfolio(String portfolioId) async {
    final response = await _apiClient.get(
      ApiConstants.portfolioById(portfolioId),
    );

    return AIPortfolioResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AIPortfolioActionResponseModel> deletePortfolio(
    String portfolioId,
  ) async {
    final response = await _apiClient.delete(
      ApiConstants.portfolioById(portfolioId),
    );

    return AIPortfolioActionResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<AIPortfolioSummaryModel>> getUserPortfolios() async {
    final response = await _apiClient.get(ApiConstants.userPortfolios);

    final list = response.data as List<dynamic>? ?? const [];

    return list
        .whereType<Map>()
        .map(
          (item) => AIPortfolioSummaryModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<LastSavedPortfolioDataModel> getLastSavedPortfolioData() async {
    final response = await _apiClient.get(
      ApiConstants.lastSavedPortfolioData,
    );

    return LastSavedPortfolioDataModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<String> previewPortfolio(String portfolioId) async {
    final response = await _apiClient.get(
      ApiConstants.portfolioPreview(portfolioId),
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'text/html',
        },
      ),
    );

    return response.data.toString();
  }

  Future<String> publishPortfolio(String portfolioId) async {
    final response = await _apiClient.post(
      ApiConstants.publishPortfolio(portfolioId),
    );

    return response.data.toString().replaceAll('"', '').trim();
  }

  Future<AIPortfolioActionResponseModel> unpublishPortfolio(
    String portfolioId,
  ) async {
    final response = await _apiClient.post(
      ApiConstants.unpublishPortfolio(portfolioId),
    );

    return AIPortfolioActionResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AIPortfolioPdfExportResponseModel> exportPortfolioPdf(
    String portfolioId,
  ) async {
    final response = await _apiClient.post(
      ApiConstants.exportPortfolioPdf(portfolioId),
    );

    return AIPortfolioPdfExportResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

// بنعمل alias واضح عشان نستخدم نفس instance اللي عندك في core/network/api_client.dart
final ApiClient apiClientSingleton = apiClient;
