import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../models/subscription_model.dart';

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

  Widget _buildSubscriptionCard(Subscription subscription) {
    final isActive = subscription.isActive;
    final isExpired = subscription.isExpired;
    final isExpiringSoon = subscription.isExpiringSoon;

    Color statusColor = Colors.green;
    String statusText = 'Active';

    if (isExpired) {
      statusColor = Colors.grey;
      statusText = 'Expired';
    } else if (isExpiringSoon) {
      statusColor = Colors.orange;
      statusText = 'Expiring Soon';
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subscription.categoryName ?? 'Unknown Category',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: statusColor.withOpacity(0.1),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Start Date:',
              value:
                  '${subscription.startDate.day}/${subscription.startDate.month}/${subscription.startDate.year}',
            ),
            _buildInfoRow(
              icon: Icons.event_busy,
              label: 'Expiry Date:',
              value:
                  '${subscription.expiryDate.day}/${subscription.expiryDate.month}/${subscription.expiryDate.year}',
            ),
            _buildInfoRow(
              icon: Icons.timer,
              label: 'Billing Cycle:',
              value: subscription.billingCycle.toUpperCase(),
            ),
            if (subscription.price != null)
              _buildInfoRow(
                icon: Icons.attach_money,
                label: 'Price:',
                value: '${subscription.price!.toStringAsFixed(0)} Birr',
                valueColor: Colors.green,
              ),
            const SizedBox(height: 12),
            if (isActive && !isExpired)
              _buildInfoRow(
                icon: Icons.warning,
                label: 'Days Remaining:',
                value: '${subscription.daysRemaining} days',
                valueColor: isExpiringSoon ? Colors.orange : Colors.green,
              ),
            const SizedBox(height: 16),
            if (isExpired || isExpiringSoon)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).push('/payment', extra: {
                      'category': {
                        'id': subscription.categoryId,
                        'name': subscription.categoryName ?? 'Category',
                        'price': subscription.price,
                        'billing_cycle': subscription.billingCycle,
                      },
                      'paymentType': 'repayment',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isExpired ? 'Renew Now' : 'Extend Now'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final activeSubscriptions = subscriptionProvider.activeSubscriptions;
    final expiredSubscriptions = subscriptionProvider.expiredSubscriptions;
    final expiringSoonSubscriptions =
        subscriptionProvider.expiringSoonSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                subscriptionProvider.loadSubscriptions(forceRefresh: true),
          ),
        ],
      ),
      body: subscriptionProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () =>
                  subscriptionProvider.loadSubscriptions(forceRefresh: true),
              child: CustomScrollView(
                slivers: [
                  if (expiringSoonSubscriptions.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expiring Soon',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text(
                                'These subscriptions will expire soon. Consider renewing to maintain access.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  if (expiringSoonSubscriptions.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildSubscriptionCard(
                            expiringSoonSubscriptions[index]),
                        childCount: expiringSoonSubscriptions.length,
                      ),
                    ),
                  if (activeSubscriptions.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Active Subscriptions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  if (activeSubscriptions.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildSubscriptionCard(activeSubscriptions[index]),
                        childCount: activeSubscriptions.length,
                      ),
                    ),
                  if (expiredSubscriptions.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Expired Subscriptions',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    ),
                  if (expiredSubscriptions.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildSubscriptionCard(expiredSubscriptions[index]),
                        childCount: expiredSubscriptions.length,
                      ),
                    ),
                  if (subscriptionProvider.allSubscriptions.isEmpty)
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
      floatingActionButton: subscriptionProvider.allSubscriptions.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                GoRouter.of(context).go('/');
              },
              icon: const Icon(Icons.explore),
              label: const Text('Browse Categories'),
            )
          : null,
    );
  }
}
