import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:flutter/material.dart';

class FilterPicker extends StatelessWidget {
  final Function(String) onFilterSelected;
  final List<String> filters;
  final String? currentFilter;

  const FilterPicker({
    super.key,
    required this.onFilterSelected,
    required this.filters,
    this.currentFilter,
  });

  @override
  Widget build(BuildContext context) {
    return BottomSheetWrapper(
      child: SizedBox(
        height: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Add Filter",
                style: TextStyle(fontSize: 20.0),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final isActive = filter == currentFilter;

                  return GestureDetector(
                    onTap: () {
                      onFilterSelected(filter);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 100,
                      margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isActive ? Colors.green : Colors.white,
                          width: isActive ? 4 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter,
                            color: isActive ? Colors.green : Colors.white,
                          ),
                          Text(
                            filter,
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.white,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isActive)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
