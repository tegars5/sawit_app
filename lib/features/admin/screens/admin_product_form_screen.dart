import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/product.dart';
import '../../../core/widgets/success_animation.dart';

class AdminProductFormScreen extends StatefulWidget {
  final Product? product; // null for create, non-null for edit

  const AdminProductFormScreen({super.key, this.product});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _isLoading = false;
  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _categoryController.text = widget.product!.category;
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stock.toString();
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await StorageService.getToken();
      if (token != null) {
        _apiClient.setToken(token);
      }

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
      };

      if (_isEditMode) {
        // Update existing product
        await _apiClient.updateProduct(
          widget.product!.id,
          productData,
          imageFile: _imageFile,
        );
        if (mounted) {
          await SuccessAnimation.show(
            context: context,
            message: 'Produk berhasil diperbarui!',
          );
        }
      } else {
        // Create new product
        await _apiClient.createProduct(
          productData,
          imageFile: _imageFile,
        );
        if (mounted) {
          await SuccessAnimation.show(
            context: context,
            message: 'Produk berhasil ditambahkan!',
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _isEditMode && widget.product!.primaryImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.product!.primaryImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate,
                                          size: 48, color: AppColors.primary),
                                      SizedBox(height: 8),
                                      Text('Tap to select image'),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 48, color: AppColors.primary),
                                  SizedBox(height: 8),
                                  Text('Tap to select image'),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: ['Premium', 'Standard', 'Economy']
                        .contains(_categoryController.text)
                    ? _categoryController.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                  DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'Economy', child: Text('Economy')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _categoryController.text = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price Field
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (Rp) *',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Price must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Stock Field
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock *',
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter stock';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter valid number';
                  }
                  if (int.parse(value) < 0) {
                    return 'Stock cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_isEditMode ? 'Update Product' : 'Create Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
