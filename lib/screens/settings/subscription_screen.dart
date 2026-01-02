import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.loadSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: subscriptionProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () => subscriptionProvider.loadSubscriptions(),
              child: CustomScrollView(
                slivers: [
                  // Active Subscriptions
                  if (subscriptionProvider.getActiveSubscriptions().isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Active Subscriptions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  if (subscriptionProvider.getActiveSubscriptions().isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final subscription = subscriptionProvider
                              .getActiveSubscriptions()[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(subscription.categoryName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Expires: ${subscription.expiryDate.day}/${subscription.expiryDate.month}/${subscription.expiryDate.year}'),
                                  Text(
                                      'Days remaining: ${subscription.daysRemaining}'),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  subscription.isExpiringSoon
                                      ? 'Expiring Soon'
                                      : 'Active',
                                  style: TextStyle(
                                    color: subscription.isExpiringSoon
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                                backgroundColor: subscription.isExpiringSoon
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                              ),
                            ),
                          );
                        },
                        childCount: subscriptionProvider
                            .getActiveSubscriptions()
                            .length,
                      ),
                    ),

                  // Expired Subscriptions
                  if (subscriptionProvider.getExpiredSubscriptions().isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Expired Subscriptions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  if (subscriptionProvider.getExpiredSubscriptions().isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final subscription = subscriptionProvider
                              .getExpiredSubscriptions()[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(subscription.categoryName),
                              subtitle: Text(
                                  'Expired: ${subscription.expiryDate.day}/${subscription.expiryDate.month}/${subscription.expiryDate.year}'),
                              trailing: OutlinedButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/payment',
                                    arguments: {
                                      'category': {
                                        'id': subscription.categoryId,
                                        'name': subscription.categoryName,
                                        'price': subscription.price,
                                      },
                                      'paymentType': 'repayment',
                                    },
                                  );
                                },
                                child: const Text('Renew'),
                              ),
                            ),
                          );
                        },
                        childCount: subscriptionProvider
                            .getExpiredSubscriptions()
                            .length,
                      ),
                    ),

                  // Empty State
                  if (subscriptionProvider.subscriptions.isEmpty)
                    const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.subscriptions,
                        title: 'No Subscriptions',
                        message: 'You don\'t have any subscriptions yet.',
                        actionText: 'Browse Categories',
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
