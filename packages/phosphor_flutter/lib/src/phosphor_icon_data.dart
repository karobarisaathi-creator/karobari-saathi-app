library phosphor_flutter;

import 'package:flutter/widgets.dart';

typedef PhosphorIconData = IconData;
typedef PhosphorFlatIconData = IconData;

class PhosphorDuotoneIconData {
 const PhosphorDuotoneIconData(this.iconData, this.secondary);

 final IconData iconData;
 final IconData secondary;
}
