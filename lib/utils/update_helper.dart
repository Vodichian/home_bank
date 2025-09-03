import 'package:bank_server/bank.dart'; // Used for Version
import 'globals.dart'; // For logger

class UpdateHelper {
  /// Checks if the current application version is older than the latest server version.
  ///
  /// [currentVersionStr] is the application's current version in "major.minor.patch" format.
  /// [latestVersionServer] is the [Version] object from the server.
  /// Returns true if an update is required, false otherwise.
  static bool isUpdateRequired(String currentVersionStr, Version latestVersionServer) {
    logger.d(
        "Comparing current app version string: '$currentVersionStr' with server Version object: ${latestVersionServer.toString()}");

    if (currentVersionStr == 'Loading...' || currentVersionStr == 'Not available') {
      logger.w("Current app version string is not available for comparison.");
      return false;
    }

    List<String> currentPartsStr = currentVersionStr.split('.');
    if (currentPartsStr.isEmpty) {
      logger.e(
          "Current app version string '$currentVersionStr' is empty or invalid.");
      return false;
    }
    
    try {
      int currentMajor = int.parse(currentPartsStr[0]);
      int currentMinor = currentPartsStr.length > 1 ? int.parse(currentPartsStr[1]) : 0;
      int currentPatch = currentPartsStr.length > 2 ? int.parse(currentPartsStr[2]) : 0;

      if (latestVersionServer.major > currentMajor) return true;
      if (latestVersionServer.major < currentMajor) return false;

      if (latestVersionServer.minor > currentMinor) return true;
      if (latestVersionServer.minor < currentMinor) return false;

      if (latestVersionServer.patch > currentPatch) return true;
      
      return false; // Same version or current is newer in patch

    } catch (e) {
      logger.e("Error parsing current app version string '$currentVersionStr': $e");
      return false; 
    }
  }
}
