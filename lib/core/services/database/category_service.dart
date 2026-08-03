import 'package:account_app/core/models/category_model.dart';
import 'base_service.dart';

class CategoryService extends BaseService {
  Future<void> addCategory(Category category) async {
    await categoriesBox?.put(category.id, category);
    notifyListeners();
    if (auth.currentUser != null) {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('categories')
          .doc(category.id)
          .set(category.toMap());
    }
  }

  Future<void> updateCategory(Category category) async {
    await categoriesBox?.put(category.id, category);
    notifyListeners();
    if (auth.currentUser != null) {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('categories')
          .doc(category.id)
          .set(category.toMap());
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    await categoriesBox?.delete(categoryId);
    if (auth.currentUser != null) {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('categories')
          .doc(categoryId)
          .delete();
    }
    notifyListeners();
  }

  List<Category> getCategories() {
    return categoriesBox?.values.toList() ?? [];
  }
}
