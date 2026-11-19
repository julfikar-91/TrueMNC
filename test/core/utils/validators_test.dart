// test/core/utils/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/utils/validators.dart';

void main() {
  group('Validators.required', () {
    test('returns error when value is null', () {
      expect(Validators.required(null, 'Title'), 'Title is required');
    });

    test('returns error when value is empty or spaces', () {
      expect(Validators.required('', 'Title'), 'Title is required');
      expect(Validators.required('   ', 'Title'), 'Title is required');
    });

    test('returns null when value is non-empty', () {
      expect(Validators.required('Flutter Developer', 'Title'), isNull);
    });
  });

  group('Validators.email', () {
    test('returns error on null or empty email', () {
      expect(Validators.email(null), 'Email address is required');
      expect(Validators.email(''), 'Email address is required');
      expect(Validators.email('   '), 'Email address is required');
    });

    test('rejects malformed email strings', () {
      const invalidEmails = [
        'plainaddress',
        '#@%^%#\$@#\$@#.com',
        '@example.com',
        'Joe Smith <email@example.com>',
        'email.example.com',
        'email@example@example.com',
        'email@example..com',
        'email@',
      ];
      for (final email in invalidEmails) {
        expect(
          Validators.email(email),
          'Please enter a valid email address',
          reason: 'Failed on invalid email: $email',
        );
      }
    });

    test('accepts valid email addresses', () {
      const validEmails = [
        'user@example.com',
        'first.last@company.org',
        'candidate123@truemnc.co.in',
        'engineer+filter@techcorp.io',
      ];
      for (final email in validEmails) {
        expect(Validators.email(email), isNull, reason: 'Rejected valid email: $email');
      }
    });
  });

  group('Validators.password', () {
    test('returns error on null or empty password', () {
      expect(Validators.password(null), 'Password is required');
      expect(Validators.password(''), 'Password is required');
    });

    test('requires minimum 8 characters', () {
      expect(
        Validators.password('Ab1'),
        'Password must be at least 8 characters long',
      );
      expect(
        Validators.password('Passw1'),
        'Password must be at least 8 characters long',
      );
    });

    test('requires at least one letter', () {
      expect(
        Validators.password('12345678'),
        'Password must contain at least one letter',
      );
      expect(
        Validators.password('9876543210!@#'),
        'Password must contain at least one letter',
      );
    });

    test('requires at least one digit', () {
      expect(
        Validators.password('abcdefgh'),
        'Password must contain at least one digit',
      );
      expect(
        Validators.password('Password!@#'),
        'Password must contain at least one digit',
      );
    });

    test('accepts passwords that meet policy', () {
      expect(Validators.password('Password1'), isNull);
      expect(Validators.password('SecurePass2026!'), isNull);
      expect(Validators.password('1234abcd'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('returns error if confirmation is empty', () {
      expect(
        Validators.confirmPassword('', 'Password1'),
        'Please confirm your password',
      );
    });

    test('returns error if passwords do not match', () {
      expect(
        Validators.confirmPassword('Password2', 'Password1'),
        'Passwords do not match',
      );
    });

    test('returns null if passwords match', () {
      expect(
        Validators.confirmPassword('Password1', 'Password1'),
        isNull,
      );
    });
  });

  group('Validators.name', () {
    test('returns error on null or empty', () {
      expect(Validators.name(null), 'Name is required');
      expect(Validators.name('   '), 'Name is required');
    });

    test('rejects names shorter than 2 chars', () {
      expect(Validators.name('A'), 'Name must be at least 2 characters');
    });

    test('rejects names containing digits or special symbols', () {
      expect(Validators.name('John123'), 'Please enter a valid name (letters only)');
      expect(Validators.name('Alice@Work'), 'Please enter a valid name (letters only)');
    });

    test('accepts valid single and multi-word names', () {
      expect(Validators.name('Sarah Connor'), isNull);
      expect(Validators.name("O'Connor"), isNull);
      expect(Validators.name('Jean-Luc'), isNull);
      expect(Validators.name('Aarav Sharma'), isNull);
    });
  });
}
