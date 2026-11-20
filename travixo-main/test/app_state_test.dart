import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_in_app/data/models.dart';
import 'package:travel_in_app/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancelBooking refunds wallet only once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs)..load();

    final initial = state.walletBalanceYer;
    final booking = state.createBooking(
      service: ServiceType.hotel,
      title: 'Test Hotel',
      provinceId: 'sanaa',
      cityId: 'sanaa',
      dateText: '2026-12-01',
      totalYer: 20000,
      payment: PaymentMethod.wallet,
    );

    expect(booking, isNotNull);
    expect(state.walletBalanceYer, initial - 20000);

    state.cancelBooking(booking!.id);
    expect(state.walletBalanceYer, initial);

    // Calling cancelBooking again must not refund twice
    state.cancelBooking(booking.id);
    expect(state.walletBalanceYer, initial);
  });

  test('addMoney ignores non-positive amounts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs)..load();

    final initial = state.walletBalanceYer;
    state.addMoney(-5000);
    state.addMoney(0);
    expect(state.walletBalanceYer, initial);
  });
}
