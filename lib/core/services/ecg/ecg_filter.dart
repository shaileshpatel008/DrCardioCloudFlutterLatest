import '../storage_service.dart';
import 'ecg_data.dart';
import 'fir_coefficients.dart';

/// Port of `SupportClass.ecgFilter`: a 200-tap FIR band filter followed by
/// a single-pole IIR high-pass filter (~0.8 Hz), applied per channel.
class EcgFilter {
  EcgFilter._();

  static const int order = 200;
  static List<double> _currentFilter = firB40;
  static List<List<double>> _filterWindow = List.generate(EcgData.noOfChannels, (_) => List.filled(order, 0.0));

  static void setFilter(String filterName) {
    _filterWindow = List.generate(EcgData.noOfChannels, (_) => List.filled(order, 0.0));
    switch (filterName) {
      case '50 Hz Notch':
        _currentFilter = firB150;
        break;
      case '5 to 40 Hz':
        _currentFilter = firB540;
        break;
      case '0 to 40 Hz':
        _currentFilter = firB40;
        break;
      case '5 to 25 Hz':
        _currentFilter = firB525;
        break;
      case '0 to 25 Hz':
        _currentFilter = firB25;
        break;
      case 'No':
        break;
      default:
        StorageService.instance.filter = '0 to 40 Hz';
        _currentFilter = firB40;
        break;
    }
  }

  static double filter(int ch, int x, double y) {
    final ecg = EcgData.instance;
    final settings = StorageService.instance;
    if (settings.filter == 'No') {
      ecg.filteredData[x][ch] = y;
      return y;
    }
    _filterWindow[ch][x % order] = y;
    double acc = 0;
    for (var i = 0; i < order; i++) {
      var j = (x % order) - i;
      if (j < 0) j += order;
      acc += _currentFilter[i] * _filterWindow[ch][j];
    }
    ecg.filteredData[x][ch] = acc;
    return acc;
  }

  static double highPassFilter(int ch, int x, double y) {
    final ecg = EcgData.instance;
    if (StorageService.instance.filter == 'No') return y;
    final highPassFilteredVal = y - ecg.preIirX[ch] + 0.992 * ecg.preIirY[ch];
    ecg.preIirY[ch] = highPassFilteredVal;
    ecg.preIirX[ch] = y;
    return highPassFilteredVal;
  }
}
