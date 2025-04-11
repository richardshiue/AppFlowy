import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class ModalPage extends StatelessWidget {
  const ModalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AFFilledButton.primary(
        builder: (context, isHovering, disabled) {
          return Text(
            'Show Modal',
            style: TextStyle(
              color: AppFlowyTheme.of(context).textColorScheme.onFill,
            ),
          );
        },
        onTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AFModalDimension.L,
                    maxHeight: AFModalDimension.L,
                  ),
                  child: AFModal(
                    headerBuilder: (context) {
                      final theme = AppFlowyTheme.of(context);
                      return AFModalHeader(
                        title: Text(
                          'Modal Title',
                          style: theme.textStyle.heading.h4(
                            color: theme.textColorScheme.primary,
                          ),
                        ),
                        onClose: () {},
                      );
                    },
                    bodyBuilder: (context) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('This is the modal body.'),
                      );
                    },
                    footerBuilder: (context) {
                      return AFModalFooter(
                        bottomEndActions: [
                          AFOutlinedButton.normal(
                            onTap: () => Navigator.of(context).pop(),
                            builder: (context, isHovering, disabled) {
                              return const Text('Cancel');
                            },
                          ),
                          AFFilledButton.primary(
                            onTap: () => Navigator.of(context).pop(),
                            builder: (context, isHovering, disabled) {
                              return Text(
                                'Apply',
                                style: TextStyle(
                                  color: AppFlowyTheme.of(context)
                                      .textColorScheme
                                      .onFill,
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
