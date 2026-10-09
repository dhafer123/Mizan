import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/quick_input/domain/usecases/ask_llm_category.dart';
import 'package:mizan/features/quick_input/domain/value_objects/category_source.dart';
import 'package:mizan/features/quick_input/domain/value_objects/category_suggestion.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

import '../../../../support/fake_expense_llm.dart';

const _gym = Category(id: 'gym', name: 'Gym', icon: 'other');
const _all = [...DefaultCategories.all, _gym];

void main() {
  late FakeExpenseLlm llm;
  late AskLlmCategory ask;

  setUp(() {
    llm = FakeExpenseLlm();
    ask = AskLlmCategory(llm, timeout: const Duration(milliseconds: 50));
  });

  test("a name from the user's categories is suggested", () async {
    llm.answer = const Ok('```json\n{"category": " gym "}\n```');
    expect(
      await ask('California', categories: _all),
      const CategorySuggestion(categoryId: 'gym', source: CategorySource.llm),
    );
    expect(llm.prompts.single, contains('Gym'));
    expect(llm.prompts.single, contains('"California"'));
  });

  group('no suggestion when', () {
    Future<void> expectNone() async =>
        expect(await ask('California', categories: _all), isNull);

    test('the name is not a category', () async {
      llm.answer = const Ok('{"category":"Sports"}');
      await expectNone();
    });

    test('the category is archived', () async {
      llm.answer = const Ok('{"category":"Gym"}');
      expect(
        await ask(
          'California',
          categories: [
            ..._all.where((c) => c != _gym),
            _gym.copyWith(archived: true),
          ],
        ),
        isNull,
      );
    });

    test('the answer is not JSON', () async {
      llm.answer = const Ok('Gym, I think.');
      await expectNone();
    });

    test('the model fails, hangs or is missing', () async {
      llm.answer = const Err(QuickInputFailure(QuickInputError.llmFailed));
      await expectNone();
      llm.answer = null;
      await expectNone();
      llm.installed = false;
      await expectNone();
    });

    test('the note is empty (and the model is not asked)', () async {
      expect(await ask('  ', categories: _all), isNull);
      expect(llm.prompts, isEmpty);
    });
  });
}
