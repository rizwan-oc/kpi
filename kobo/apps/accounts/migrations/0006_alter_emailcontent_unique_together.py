# Generated by Django 3.2.15 on 2023-04-07 23:42

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0005_do_nothing'),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name='emailcontent',
            unique_together={('email_name', 'section_name')},
        ),
    ]
