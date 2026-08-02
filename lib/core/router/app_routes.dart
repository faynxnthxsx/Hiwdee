/// เส้นทางทั้งหมดในแอป รวมไว้ที่เดียวกันกัน path พิมพ์ผิด
abstract final class AppRoutes {
  static const feed = '/feed';
  static const trips = '/trips';
  static const orders = '/orders';
  static const me = '/me';

  static const requestNew = '/request/new';
  static String requestDetail(String id) => '/request/$id';
  static const requestDetailPattern = '/request/:id';

  static String orderDetail(String id) => '/orders/$id';
  static const orderDetailPattern = '/orders/:id';

  static const tripNew = '/trips/new';

  static const addresses = '/addresses';
  static const addressForm = '/addresses/form';

  static const carrierOnboard = '/carrier/onboard';

  static const calculator = '/calculator';
  static const customsGuide = '/calculator/guide';
}
