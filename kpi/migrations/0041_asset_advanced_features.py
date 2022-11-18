# Generated by Django 2.2.7 on 2021-11-17 22:42

from django.db import migrations
import kpi.fields.lazy_default_jsonb


class Migration(migrations.Migration):

    dependencies = [
        ('kpi', '0040_synchronous_export'),
    ]

    operations = [
        migrations.AddField(
            model_name='asset',
            name='advanced_features',
            field=kpi.fields.lazy_default_jsonb.LazyDefaultJSONBField(default=dict),
        ),
    ]
