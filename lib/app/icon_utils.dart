import 'package:flutter/material.dart';

IconData iconForName(String name) => switch (name) {
  'water_drop' => Icons.water_drop,
  'bolt' => Icons.bolt,
  'cleaning_services' => Icons.cleaning_services,
  'chair' => Icons.chair,
  'format_paint' => Icons.format_paint,
  'ac_unit' => Icons.ac_unit,
  'power' => Icons.power,
  'toys' => Icons.toys,
  'plumbing' => Icons.plumbing,
  _ => Icons.home_repair_service,
};
