# Generated by Django 3.2.15 on 2023-03-28 14:54

from django.db import migrations, models

from kpi.fields.kpi_uid import KpiUidField, UUID_LENGTH


def add_uid_to_extra_details(apps, schema_editor):
    ExtraUserDetail = apps.get_model('hub', 'ExtraUserDetail')  # noqa
    batch_size = 2000
    qs = ExtraUserDetail.objects.only('uid').filter(uid='')
    batch = []
    for user_details in qs.iterator(chunk_size=batch_size):
        user_details.uid = KpiUidField.generate_unique_id('u')
        batch.append(user_details)
        if len(batch) >= batch_size:
            ExtraUserDetail.objects.bulk_update(batch, ['uid'])
            batch = []
    if batch:
        ExtraUserDetail.objects.bulk_update(batch, ['uid'])


def noop(*args, **kwargs):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('hub', '0008_add_removal_dates_to_extrauserdetail'),
    ]

    operations = [
        migrations.AddField(
            model_name='extrauserdetail',
            name='uid',
            field=models.CharField(
                default='',
                max_length=UUID_LENGTH + 1,
            ),
        ),
        migrations.RunPython(add_uid_to_extra_details, noop),
        migrations.AlterField(
            model_name='extrauserdetail',
            name='uid',
            field=KpiUidField(uid_prefix='u'),
        )
    ]
